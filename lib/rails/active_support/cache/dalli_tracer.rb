require "method/tracer"

module Dalli
  class Tracer
    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil)
        ::Dalli::Server.class_eval do
          @tracer = tracer
          @active_span = active_span

          class << self
            attr_reader :tracer, :active_span
          end

          def tracer
            self.class.tracer
          end

          def active_span
            self.class.active_span
          end

          alias_method :request_without_instrumentation, :request

          def request(op, *args)
            tags = {
              'component' => 'Dalli::Server',
              'span.kind' => 'client',
              'db.statement' => op.to_s,
              'db.type' => 'memcached',
              'peer.hostname' => hostname,
              'peer.port' => port,
              'peer.weight' => weight
            }
            Method::Tracer.trace("Dalli::Server#request", tracer: tracer, child_of: active_span, tags: tags) do
              request_without_instrumentation(op, *args)
            end
          end
        end

        ::Dalli::Client.class_eval do
          @tracer = tracer
          @active_span = active_span

          class << self
            attr_reader :tracer, :active_span
          end

          def tracer
            self.class.tracer
          end

          def active_span
            self.class.active_span
          end

          alias_method :perform_without_instrumentation, :perform

          def perform(*args)
            Method::Tracer.trace("Dalli::Client#perform", tracer: tracer, child_of: active_span) do
              perform_without_instrumentation(*args)
            end
          end
        end
      end

      def remove_instrumentation
        ::Dalli::Server.class_eval do
          alias_method :request, :request_without_instrumentation
          remove_method :request_without_instrumentation
        end

        ::Dalli::Client.class_eval do
          alias_method :perform, :perform_without_instrumentation
          remove_method :perform_without_instrumentation
        end
      end
    end
  end
end
