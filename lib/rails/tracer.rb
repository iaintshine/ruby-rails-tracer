require "rails/span_helpers"
require "rails/rack/tracer"
require "rails/active_record/tracer"
require "rails/active_support/cache/tracer"

module Rails
  module Tracer
    class << self
      def instrument(tracer: OpenTracing.global_tracer, active_span: nil, dalli: false)
        Rails::Rack::Tracer.instrument
        ActiveSupport::Cache::Tracer.instrument(tracer: tracer, active_span: active_span, dalli: dalli)
        ActiveRecord::Tracer.instrument(tracer: tracer, active_span: active_span)
      end

      def disable
        ActiveRecord::Tracer.disable
        ActiveSupport::Cache::Tracer.disable
      end
    end
  end
end
