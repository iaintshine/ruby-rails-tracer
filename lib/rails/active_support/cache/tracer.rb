module ActiveSupport
  module Cache
    module Tracer
      class << self
        # TODO: In Rails 4.0+ it's possible to  subscribe to start events
        def instrument(tracer: OpenTracing.global_tracer, active_span: nil)
          events = %w(read write generate delete clear)
          events.each do |event|
            ActiveSupport::Notifications.subscribe("cache_#{event}.active_support") do |*args|
              ActiveSupport::Cache::Tracer.instrument_event(tracer: tracer,
                                                            active_span: active_span,
                                                            event: event,
                                                            args: args)
            end
          end
        end

        def instrument_event(tracer: OpenTracing.global_tracer, active_span: nil, event:, args:)
          _, start, finish, _, payload = *args

          span = start_span("cache.#{event}",
                            event: event,
                            tracer: tracer,
                            active_span: active_span,
                            start_time: start,
                            **payload)

          span.finish(end_time: finish)
        end

        def start_span(operation_name, tracer: OpenTracing.global_tracer, active_span: nil, start_time: Time.now, event:, **fields)
          span = tracer.start_span(operation_name,
                                   child_of: active_span.respond_to?(:call) ? active_span.call : active_span,
                                   start_time: start_time,
                                   tags: {
                                    'component' => 'ActiveSupport::Cache',
                                    'span.kind' => 'client',
                                    'cache.key' => fields.fetch(:key, 'unknown')
                                   })

          if event == 'read'
            span.set_tag('cache.hit', fields.fetch(:hit, false))
          end

          span
        end
      end
    end
  end
end
