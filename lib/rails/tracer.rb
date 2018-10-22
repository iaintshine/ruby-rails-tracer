require "rails/span_helpers"
require "rails/rack/tracer"
require "rails/active_record/tracer"
require "rails/active_support/cache/tracer"
require "rails/action_controller/tracer"

module Rails
  module Tracer
    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil,
                     rack: false, middlewares: Rails.configuration.middleware,
                     active_record: true,
                     active_support_cache: true, dalli: false,
                     action_controller: true,
                     full_trace: true)
        Rails::Rack::Tracer.instrument(tracer: tracer, middlewares: middlewares) if rack
        ActiveRecord::Tracer.instrument(tracer: tracer, active_span: active_span) if active_record
        ActiveSupport::Cache::Tracer.instrument(tracer: tracer, active_span: active_span, dalli: dalli) if active_support_cache
        ActionController::Tracer.instrument(tracer: tracer, active_span: active_span) if action_controller

        # hold the requests until they can be written
        @requests = {} if full_trace
      end

      def disable
        ActiveRecord::Tracer.disable
        ActiveSupport::Cache::Tracer.disable
        Rails::Rack::Tracer.disable
        ActionController::Tracer.disable
      end

      def requests
        @requests
      end
    end
  end
end
