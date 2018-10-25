module Rails
  module Tracer
    module SpanHelpers
      class << self
        def set_error(span, exception)
          span.set_tag('error', true)

          case exception
          when Array
            exception_class, exception_message = exception
            span.log(event: 'error', :'error.kind' => exception_class, message: exception_message)
          when Exception
            span.log(event: 'error', :'error.object' => exception)
          end
        end
        def rack_span(payload)
          # if rack tracing is disabled, this will just be nil
          headers = payload.fetch(:headers, nil)
          headers.env['rack.span'] if !headers.nil?
        end
      end
    end
  end
end
