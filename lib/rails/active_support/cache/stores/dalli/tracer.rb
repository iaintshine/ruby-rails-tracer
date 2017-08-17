module Dalli
  class Tracer
    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil)
        ::Dalli::Server.class_eval do
          alias_method :request_without_instrumentation, :request

          def tracer
            OpenTracing.global_tracer
          end

          def active_span
            tracer.active_span
          end

          def request(op, *args)
            span = tracer.start_span("Dalli::Server#request",
                                   child_of: active_span,
                                   tags: {
                                    'component' => 'Dalli::Server',
                                    'span.kind' => 'client',
                                    'db.statement' => op,
                                    'db.type' => 'memcached',
                                    'peer.hostname' => hostname,
                                    'peer.port' => port,
                                    'peer.weight' => weight
                                   })

            request_without_instrumentation(op, *args)
          ensure
            span&.finish
          end
        end

        ::Dalli::Client.class_eval do
          alias_method :perform_without_instrumentation, :perform

          def tracer
            OpenTracing.global_tracer
          end

          def active_span
            tracer.active_span
          end

          def perform(*args)
            span = tracer.start_span("Dalli::Client#perform", child_of: active_span)
            perform_without_instrumentation(*args)
          ensure
            span&.finish
          end
        end
      end
    end
  end
end
