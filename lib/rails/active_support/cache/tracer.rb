require 'rails/active_support/cache/core_ext'
require 'rails/active_support/cache/manual_tracer'
require 'rails/active_support/cache/subscriber'

module ActiveSupport
  module Cache
    module Tracer
      class << self
        def instrument(tracer: OpenTracing.global_tracer, active_span: nil, dalli: false)
          clear_subscribers
          events = %w(read write generate delete clear)
          @subscribers = events.map do |event|
            subscriber = ActiveSupport::Cache::Tracer::Subscriber.new(tracer: tracer,
                                                                      active_span: active_span,
                                                                      event: event)
            ActiveSupport::Notifications.subscribe("cache_#{event}.active_support", subscriber)
          end

          instrument_dalli(tracer: tracer, active_span: active_span) if dalli

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

        def instrument_dalli(tracer:, active_span:)
          return unless defined?(ActiveSupport::Cache::DalliStore)
          require 'rails/active_support/cache/dalli_tracer'

          Dalli::Tracer.instrument(tracer: tracer, active_span: active_span)
          instrument_dalli_logger(active_span: active_span)
        end

        def instrument_dalli_logger(active_span:, level: Logger::ERROR)
          return unless defined?(Tracing::Logger)
          return unless active_span
          return if [Tracing::Logger, Tracing::CompositeLogger].any? { |t| Dalli.logger.is_a?(t) }

          tracing_logger = Tracing::Logger.new(active_span: active_span, level: level)
          loggers = [tracing_logger, Dalli.logger].compact
          Dalli.logger = Tracing::CompositeLogger.new(*loggers)
        end
      end
    end
  end
end
