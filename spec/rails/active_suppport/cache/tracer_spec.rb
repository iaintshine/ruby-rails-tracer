require "spec_helper"

RSpec.describe ActiveSupport::Cache::Tracer do
  let(:tracer) { Test::Tracer.new }
  let(:test_key) { "test-key" }

  describe "active span propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      @cache_tracer = ActiveSupport::Cache::Tracer.instrument(tracer: tracer, active_span: -> { root_span })
      Rails.cache.read(test_key)
    end

    after do
      ActiveSupport::Notifications.unsubscribe(@cache_tracer)
      Rails.cache.clear
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
      @cache_tracer = ActiveSupport::Cache::Tracer.instrument(tracer: tracer)
      Rails.cache.read(test_key)
    end

    after do
      ActiveSupport::Notifications.unsubscribe(@cache_tracer)
      Rails.cache.clear
    end

    it "creates a new span" do
      expect(tracer.finished_spans).not_to be_empty
    end

    it "sets operation_name to event's name" do
      expect(tracer.finished_spans.first.operation_name).to eq("cache.read")
    end

    it "sets standard OT tags" do
      tags = tracer.finished_spans.first.tags
      [
        ['component', 'ActiveSupport::Cache'],
        ['span.kind', 'client']
      ].each do |key, value|
        expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got '#{tags[key]}'"
      end
    end

    it "sets cache specific OT tags" do
      tags = tracer.finished_spans.first.tags
      [
        ['cache.key', test_key],
      ].each do |key, value|
        expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got #{tags[key]}"
      end
    end

    context "cache entry not found during read" do
      it "sets cache.hit tag to false" do
        Rails.cache.read(test_key)
        tags = tracer.finished_spans.first.tags
        expect(tags['cache.hit']).to eq(false)
      end
    end

    context "cache entry found during read" do
      it "sets cache.hit tag to true" do
        Rails.cache.write(test_key, "a value")
        Rails.cache.read(test_key)
        tags = tracer.finished_spans.last.tags
        expect(tags['cache.hit']).to eq(true)
      end
    end
  end
end
