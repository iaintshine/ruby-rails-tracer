
module ActionController
  module Tracer
    COMPONENT = "ActionController".freeze

    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil)

        @subscribers = []
        @subscribers << ::ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |*args|
          ActionController::Tracer.start_processing(tracer: tracer, active_span: active_span, args: args)
        end
        @subscribers << ::ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
          ActionController::Tracer.process_action(tracer: tracer, active_span: active_span, args: args)
        end
      end

      def disable
        @subscribers.each do |subscriber|
          ::ActiveSupport::Notifications.unsubscribe(subscriber)
        end
        @subscribers = []
        self
      end

      def start_processing(tracer: OpenTracing.global_tracer, active_span: nil, args: {})
        event, start, finish, id, payload = *args

        name = "#{payload.fetch(:controller)}##{payload.fetch(:action)} #{event}"
        tags = {
          'component' => COMPONENT,
          'span.kind' => 'client',
          'http.method' => payload.fetch(:method),
          'http.path' => payload.fetch(:path),
        }

        if Rails::Tracer.requests.nil?
          span = tracer.start_span(name,
                                   child_of: active_span.respond_to?(:call) ? active_span.call : active_span,
                                   start_time: start,
                                   tags: tags)

          span.finish(end_time: finish)
        else
          spaninfo = {
            'event' => event,
            'name' => name,
            'start' => start,
            'finish' => finish,
            'tags' => tags,
          }

          Rails::Tracer::SpanHelpers.defer_span(id: id, spaninfo: spaninfo)
        end
      end

      def process_action(tracer: OpenTracing.global_tracer, active_span: nil, args: {})
        event, start, finish, id, payload = *args

        name = "#{payload.fetch(:controller)}##{payload.fetch(:action)} #{event}"
        tags = {
          'component' => COMPONENT,
          'span.kind' => 'client',
          'http.method' => payload.fetch(:method),
          'http.status_code' => payload.fetch(:status),
          'http.path' => payload.fetch(:path),
          'view.runtime' => payload.fetch(:view_runtime),
          'db.runtime' => payload.fetch(:db_runtime),
        }

        if Rails::Tracer.requests.nil? # TODO replace with better check
          # write out the span
          span = tracer.start_span(name,
                                   child_of: active_span.respond_to?(:call) ? active_span.call : active_span,
                                   start_time: start,
                                   tags: tags)

          span.finish(end_time: finish)
        else
          # defer the spans if full_trace is configured
          spaninfo = {
            'event' => event,
            'name' => name,
            'start' => start,
            'finish' => finish,
            'tags' => tags,
          }

          Rails::Tracer::SpanHelpers.defer_span(id: id, spaninfo: spaninfo)
        end

      end
    end
  end
end
