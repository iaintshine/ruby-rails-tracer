require "spec_helper"

RSpec.describe ActiveRecord::Tracer do
  let(:tracer) { Test::Tracer.new }

  describe "active span propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      @active_record_tracer = ActiveRecord::Tracer.instrument(tracer: tracer, active_span: -> { root_span })
      Article.first
    end

    after do
      ActiveSupport::Notifications.unsubscribe(@active_record_tracer)
    end

    it "creates the new span with active span trace_id" do
      cache_span = tracer.finished_spans.last
      expect(cache_span.context.trace_id).to eq(root_span.context.trace_id)
    end

    it "creates the new span with active span as a parent" do
      cache_span = tracer.finished_spans.last
      expect(cache_span.context.parent_span_id).to eq(root_span.context.span_id)
    end
  end

  describe "auto-instrumentation" do
    before do
      @active_record_tracer = ActiveRecord::Tracer.instrument(tracer: tracer)
      Article.first
    end

    after do
      ActiveSupport::Notifications.unsubscribe(@active_record_tracer)
    end

    it "creates a new span" do
      expect(tracer.finished_spans).not_to be_empty
    end

    it "sets operation_name to event's name" do
      expect(tracer.finished_spans.first.operation_name).to eq("Article Load")
    end

    it "sets standard OT tags" do
      tags = tracer.finished_spans.first.tags
      [
        ['component', 'ActiveRecord'],
        ['span.kind', 'client']
      ].each do |key, value|
        expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got '#{tags[key]}'"
      end
    end

    it "sets database specific OT tags" do
      tags = tracer.finished_spans.first.tags
      [
        ['db.type', 'sql'],
        ['db.vendor', 'sqlite3'],
        ['db.statement', 'SELECT  "articles".* FROM "articles" ORDER BY "articles"."id" ASC LIMIT ?'],
      ].each do |key, value|
        expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got #{tags[key]}"
      end
    end
  end
end
