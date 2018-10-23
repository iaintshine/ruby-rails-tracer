require 'pp'
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

        def defer_span(id:, spaninfo:, tracer: OpenTracing.global_tracer)
          if Rails::Tracer.requests[id].nil?
            Rails::Tracer.requests[id] = []
          end

          # TODO if this is a process_action then the request is complete, so we can write out the span
          if spaninfo['event'] == 'process_action.action_controller'
            process_action_span = tracer.start_span(spaninfo['name'],
                                                    start_time: spaninfo['start'],
                                                    tags: spaninfo['tags'])
            write_spans(notifications: Rails::Tracer.requests[id], parent_span: process_action_span)
            process_action_span.finish(end_time: spaninfo['finish'])

            # now that all spans are written, this can be deleted.
            Rails::Tracer.requests.delete(id)
          else
            Rails::Tracer.requests[id] << spaninfo
          end

        end

        def write_spans(notifications: [], parent_span: nil, tracer: OpenTracing.global_tracer)
          notifications.each do |spaninfo|
            span = tracer.start_span(spaninfo['name'],
                                     child_of: parent_span,
                                     start_time: spaninfo['start'],
                                     tags: spaninfo['tags'])

            span.finish(end_time: spaninfo['finish'])
          end
        end
      end
    end
  end
end
