module ActionController
  module Tracer
    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil)
        @subscribers = [
          instrument_start_processing(tracer, active_span),
          instrument_process_action(tracer, active_span)
        ]

        self
      end

      def disable
        if  @subscribers
          @subscribers.each { |subscriber| ActiveSupport::Notifications.unsubscribe(subscriber) }
          @subscribers.clear
        end

        self
      end
      alias :clear_subscribers :disable

      private

      def instrument_start_processing(tracer, active_span)
        ::ActiveSupport::Notifications.subscribe('start_processing.action_controller') do |*args|
        end
      end

      def instrument_process_action(tracer, active_span)
        ::ActiveSupport::Notifications.subscribe('process_action.action_controller') do |*args|
        end
      end
    end
  end
end
