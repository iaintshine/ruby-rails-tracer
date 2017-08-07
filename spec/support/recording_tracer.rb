class RecordingTracer
  attr_reader :finished_spans

  def initialize
    @finished_spans = []
  end

  def start_span(operation_name, tags: {}, **)
    Span.new(self, operation_name, tags)
  end

  def inject(*)
  end

  def extract(*)
  end

  class Span
    class SpanAlreadyFinished < StandardError; end

    attr_accessor :operation_name
    attr_reader :tags, :logs

    def initialize(tracer, operation_name, tags)
      @tracer = tracer
      @operation_name = operation_name
      @tags = tags
      @logs = []
      @open = true
    end

    def finish
      ensure_in_progress!

      @open = false
      @tracer.finished_spans << self
    end

    def context
      {}
    end

    def set_tag(key, value)
      ensure_in_progress!

      @tags[key] = value
      self
    end

    def log(event: nil, timestamp: Time.now, **fields)
      ensure_in_progress!

      @logs << {event: event, timestamp: timestamp, fields: fields}
    end

  private

    def ensure_in_progress!
      unless @open
        raise SpanAlreadyFinished.new("No modification operations allowed. The span is already finished.")
      end
    end
  end
end
