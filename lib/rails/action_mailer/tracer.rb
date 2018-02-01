module ActionMailer
  module Tracer
    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil)
        clear_subscribers
        @subscriber = ::ActiveSupport::Notifications.subscribe('deliver.action_mailer') do |*args|
            ActionMailer::Tracer.mail(tracer: tracer, active_span: active_span, args: args)
        end
      end

      def disable
        if @subscriber
          ActiveSupport::Notifications.unsubscribe(@subscriber)
          @subscriber = nil
        end
      end
      alias :clear_subscribers :disable

      def mail(tracer: OpenTracing.global_tracer, active_span: nil, args:)
        _, start, finish, _, payload = *args

        span = start_span(payload.fetch(:mailer),
                          tracer: tracer,
                          active_span: active_span,
                          start_time: start,
                          message_id: payload.fetch(:message_id),
                          to: payload.fetch(:to),
                          from: payload.fetch(:from))
        if payload[:exception]
          Rails::Tracer::SpanHelpers.set_error(span, payload[:exception_object] || payload[:exception])
        end

        span.finish(end_time: finish)
      end

      def start_span(operation_name, tracer: OpenTracing.global_tracer, active_span: nil, start_time: Time.now, **fields)
        span = tracer.start_span(operation_name,
                                 child_of: active_span.respond_to?(:call) ? active_span.call : active_span,
                                 start_time: start_time,
                                 tags: {
                                  'component' => 'ActionMailer',
                                  'span.kind' => 'client',
                                  'mail.message_id' => fields.fetch(:message_id),
                                  'mail.to' => fields.fetch(:to),
                                  'mail.from' => fields.fetch(:from)
                                 })
        span
      end
    end
  end
end
