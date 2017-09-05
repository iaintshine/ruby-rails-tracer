module ActiveSupport
  module Cache
    module Tracer
      class Subscriber
        attr_reader :tracer, :active_span, :event, :operation_name

        def initialize(tracer: OpenTracing.global_tracer, active_span: nil, event:)
          @tracer = tracer
          @active_span = active_span
          @event = event
          @operation_name = "cache.#{event}"
        end

        # For compatibility with Rails 3.2
        def call(*args)
          _, start, finish, _, payload = *args

          span = Tracer.start_span(operation_name,
                                    event: event,
                                    tracer: tracer,
                                    active_span: active_span,
                                    start_time: start,
                                    **payload)

          if payload[:exception]
            Rails::Tracer::SpanHelpers.set_error(span, payload[:exception_object] || payload[:exception])
          end

          span.finish(end_time: finish)
        end

        def start(name, _, payload)
          span = tracer.start_span(operation_name,
                                   child_of: active_span.respond_to?(:call) ? active_span.call : active_span,
                                   tags: {
                                    'component' => 'ActiveSupport::Cache',
                                    'span.kind' => 'client'
                                   })

          payload[:__OT_SPAN__] = span
        end

        def finish(name, _, payload)
          span = payload[:__OT_SPAN__]
          return unless span

          span.set_tag('cache.key', payload.fetch(:key, 'unknown'))

          if event == 'read'
            span.set_tag('cache.hit', payload.fetch(:hit, false))
          end

          if payload[:exception]
            Rails::Tracer::SpanHelpers.set_error(span, payload[:exception_object] || payload[:exception])
          end

          span.finish
        end
      end
    end
  end
end
