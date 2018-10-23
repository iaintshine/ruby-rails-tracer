
module ActionView
  module Tracer
    COMPONENT = "ActionView".freeze

    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil)
        @subscribers = []
        @subscribers << ::ActiveSupport::Notifications.subscribe('render_template.action_view') do |*args|
          ActionView::Tracer.render_template(tracer: tracer, active_span: active_span, args: args)
        end
        @subscribers << ::ActiveSupport::Notifications.subscribe('render_partial.action_view') do |*args|
          ActionView::Tracer.render_partial(tracer: tracer, active_span: active_span, args: args)
        end
        @subscribers << ::ActiveSupport::Notifications.subscribe('render_collection.action_view') do |*args|
          ActionView::Tracer.render_collection(tracer: tracer, active_span: active_span, args: args)
        end
      end

      def disable
        @subscribers.each do |subscriber|
          ::ActiveSupport::Notifications.unsubscribe(subscriber)
        end
        @subscribers = []
        self
      end

      def render_template(tracer: OpenTracing.global_tracer, active_span: nil, args: {})
        event, start, finish, id, payload = *args

        tags = {
          'component' => COMPONENT,
          'span.kind' => 'client',
          'template_path' => payload.fetch(:identifier),
          'layout' => payload.fetch(:layout),
        }

        handle_notification(tracer: tracer,
                            active_span: active_span,
                            id: id,
                            name: event,
                            tags: tags,
                            start: start,
                            finish: finish)
      end

      def render_partial(tracer: OpenTracing.global_tracer, active_span: nil, args: {})
        event, start, finish, id, payload = *args

        tags = {
          'component' => COMPONENT,
          'span.kind' => 'client',
          'template_path' => payload.fetch(:identifier),
        }

        handle_notification(tracer: tracer,
                            active_span: active_span,
                            id: id,
                            name: event,
                            tags: tags,
                            start: start,
                            finish: finish)
      end

      def render_collection(tracer: OpenTracing.global_tracer, active_span: nil, args: {})
        event, start, finish, id, payload = *args

        tags = {
          'component' => COMPONENT,
          'span.kind' => 'client',
          'template_path' => payload.fetch(:identifier),
          'collection_size' => payload.fetch(:count),
        }

        handle_notification(tracer: tracer,
                            active_span: active_span,
                            id: id,
                            name: event,
                            tags: tags,
                            start: start,
                            finish: finish)
      end

      def handle_notification(tracer:, active_span:, id:, name:, tags:, start:, finish:)
        if !Rails::Tracer::Defer.enabled
          span = tracer.start_span(name,
                                   child_of: active_span.respond_to?(:call) ? active_span.call : active_span,
                                   start_time: start,
                                   tags: tags)

          span.finish(end_time: finish)
        else
          spaninfo = {
            'event' => name,
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
