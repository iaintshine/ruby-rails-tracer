
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
        @subscribers.clear
        self
      end

      def start_processing(tracer: OpenTracing.global_tracer, active_span: nil, args: {})
        event, start, finish, id, payload = *args

        # extract the rack context, if it exists
        # it seems like this might be the earliest place env is available
        rack_span = Rails::Tracer::SpanHelpers.rack_span(payload)
        Rails::Tracer::Defer.add_parent(id, rack_span)

        path = payload.fetch(:path)
        name = "#{payload.fetch(:controller)}##{payload.fetch(:action)} #{event} #{path}"
        tags = {
          'component' => COMPONENT,
          'span.kind' => 'client',
          'http.method' => payload.fetch(:method),
          'http.path' => path,
        }

        if !Rails::Tracer::Defer.enabled
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

          Rails::Tracer::Defer.defer_span(id: id, spaninfo: spaninfo)
        end
      end

      def process_action(tracer: OpenTracing.global_tracer, active_span: nil, args: {})
        event, start, finish, id, payload = *args

        path = payload.fetch(:path)
        name = "#{payload.fetch(:controller)}##{payload.fetch(:action)} #{path}"
        tags = {
          'component' => COMPONENT,
          'span.kind' => 'client',
          'http.method' => payload.fetch(:method),
          'http.status_code' => payload.fetch(:status),
          'http.path' => path,
          'view.runtime' => payload.fetch(:view_runtime),
          'db.runtime' => payload.fetch(:db_runtime),
        }

        if !Rails::Tracer::Defer.enabled
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

          Rails::Tracer::Defer.defer_span(id: id, spaninfo: spaninfo)
        end
      end
    end
  end
end
