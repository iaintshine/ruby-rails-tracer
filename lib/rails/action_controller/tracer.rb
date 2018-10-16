
module ActionController
  module Tracer
    COMPONENT = "ActionController".freeze

    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil)
        @subscriber = ::ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
          ActionController::Tracer.process_action(tracer: tracer, args: args)
        end
      end

      def disable
        if @subscriber
          ::ActiveSupport::Notifications.unsubscribe(@subscriber)
          @subscriber = nil
        end

        self
      end

      def process_action(tracer: nil, args: nil)
        event, start, finish, id, payload = *args

        controller = payload.fetch(:controller)
        action = payload.fetch(:action)
        method = payload.fetch(:method)
        path = payload.fetch(:path)
        status = payload.fetch(:status)
        view_runtime = payload.fetch(:view_runtime)
        db_runtime = payload.fetch(:db_runtime)

        span = tracer.start_span("#{controller}##{action}",
                          start_time: start,
                          tags: {
                            'component' => COMPONENT,
                            'span.kind' => 'client',
                            'http.method' => method,
                            'http.status_code' => status,
                            'view.runtime' => view_runtime,
                            'db.runtime' => db_runtime,
                          }
                         )

        span.finish(end_time: finish)
      end
    end
  end
end
