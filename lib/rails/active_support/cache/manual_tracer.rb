module ActiveSupport
  module Cache
    module Tracer
      class << self
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
