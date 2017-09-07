module Rails
  module Rack
    class Tracer
      class << self
        def instrument(tracer: OpenTracing.global_tracer, middlewares: Rails.configuration.middleware)
          return unless defined?(::Rack::Tracer)
          @owns_all_middlewares = false
          unless middlewares.include?(::Rack::Tracer)
            middlewares.use(::Rack::Tracer, tracer: tracer)
            @owns_all_middlewares = true
          end
          middlewares.insert_after(::Rack::Tracer, Rails::Rack::Tracer)
        end

        def disable(middlewares: Rails.configuration.middleware)
          middlewares.delete(Rails::Rack::Tracer)
          if @owns_all_middlewares
            middlewares.delete(::Rack::Tracer)
            @owns_all_middlewares = false
          end
        rescue
        end
      end

      def initialize(app)
        @app = app
      end

      def call(env)
        @app.call(env)
      ensure
        enhance_rack_span(env)
      end

      private

      def enhance_rack_span(env)
        span = extract_span(env)
        if span && route_found?(env)
          span.operation_name = operation_name(env)
        end
      end

      def extract_span(env)
        env['rack.span']
      end

      def route_found?(env)
        env["action_dispatch.request.path_parameters"]
      end

      def operation_name(env)
        path_parameters = env["action_dispatch.request.path_parameters"]
        action_controller = env["action_controller.instance"]
        controller = action_controller ? action_controller.class.to_s : path_parameters[:controller]
        action = path_parameters[:action]
        "#{controller}##{action}"
      end
    end
  end
end
