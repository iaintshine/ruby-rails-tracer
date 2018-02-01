require "spec_helper"

RSpec.describe ActionMailer::Tracer do
  let(:tracer) { Test::Tracer.new }

  describe "active span propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      ActionMailer::Tracer.instrument(tracer: tracer, active_span: -> { root_span })
      ArticleMailer.notify_new_article.deliver
    end

    after do
      ActionMailer::Tracer.disable
    end

    it "creates the new span with active span trace_id" do
      expect(tracer).to have_traces(1)
    end

    it "creates the new span with active span as a parent" do
      cache_span = tracer.finished_spans.last
      expect(cache_span).to be_child_of(root_span)
    end
  end

  describe "auto-instrumentation" do
    before do
      ActionMailer::Tracer.instrument(tracer: tracer)
      ArticleMailer.notify_new_article.deliver
    end

    after do
      ActionMailer::Tracer.disable
    end

    it "creates a new span" do
      expect(tracer).to have_spans
    end

    it "sets operation_name to event's name" do
      expect(tracer).to have_span("ArticleMailer")
    end

    it "sets standard OT tags" do
      [
        ['component', 'ActionMailer'],
        ['span.kind', 'client']
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end
  end
end
