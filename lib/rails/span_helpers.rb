module Rails
  module Tracer
    module SpanHelpers
      class << self
        def set_error(span, exception)
          span.set_tag('error', true)
          span.log(event: 'error', :'error.object' => exception)
        end
      end
    end
  end
end
