
module Rails
  module Tracer
    module Defer
      class << self
        attr_reader :enabled

        def enable
          @enabled = true
          @requests = {}
        end

        def defer_span(id:, spaninfo:, tracer: OpenTracing.global_tracer)
          if @requests[id].nil?
            @requests[id] = []
          end

          # if this is a process_action then the request is complete, so we can write out the span
          if spaninfo['event'] == 'process_action.action_controller'
            process_action_span = tracer.start_span(spaninfo['name'],
                                                    start_time: spaninfo['start'],
                                                    tags: spaninfo['tags'])
            write_spans(notifications: @requests[id], parent_span: process_action_span)
            process_action_span.finish(end_time: spaninfo['finish'])

            # now that all spans are written, this can be deleted.
            @requests.delete(id)
          else
            @requests[id] << spaninfo
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
