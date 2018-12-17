
module Rails
  module Tracer
    module Defer
      class << self
        attr_reader :enabled

        def enable
          @enabled = true
          @requests = {}
          @parent_spans = {}
        end

        def requests
          @requests
        end

        def add_parent(id, span)
          @parent_spans[id] = span
        end

        def defer_span(id:, spaninfo:, tracer: OpenTracing.global_tracer)
          if @requests[id].nil?
            @requests[id] = []
          end

          # if this is a process_action then the request is complete, so we can write out the span
          if spaninfo['event'] == 'process_action.action_controller'

            # check if we've registered a parent span
            # at this point, only a rack span
            parent_span = @parent_spans[id]

            if parent_span.nil?
              # use process_action as the parent span for this request
              parent_span = tracer.start_span(spaninfo['name'],
                                              start_time: spaninfo['start'],
                                              tags: spaninfo['tags'])
            else
              # if we have another parent span and process_action will
              # not need to be used as a parent span, add it to the list
              # to write out with all the others
              @requests[id] << spaninfo
            end

            # each of the stored notifications with the current request id will
            # be written out as spans
            write_spans(notifications: @requests[id], parent_span: parent_span)

            # the rack span will finish on its own, but we need to finish if we
            # started a parent span using the process_action notification
            parent_span.finish(end_time: spaninfo['finish']) if @parent_spans[id].nil?

            # now that all spans are written, these can be deleted to free up space
            @requests.delete(id)
            @parent_spans.delete(id)
          else
            # this isn't a span that specifically means anything, so
            # just save the span info
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
