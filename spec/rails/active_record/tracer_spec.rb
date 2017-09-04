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
      expect(tracer).to have_traces(1)
    end

    it "creates the new span with active span as a parent" do
      cache_span = tracer.finished_spans.last
      expect(cache_span).to be_child_of(root_span)
    end
  end

  describe "auto-instrumentation" do
    before do
      @active_record_tracer = ActiveRecord::Tracer.instrument(tracer: tracer)
      Article.count
    end

    after do
      ActiveSupport::Notifications.unsubscribe(@active_record_tracer)
    end

    it "creates a new span" do
      expect(tracer).to have_spans
    end

    it "sets operation_name to event's name" do
      expect(tracer).to have_span("sql.query")
    end

    it "sets standard OT tags" do
      [
        ['component', 'ActiveRecord'],
        ['span.kind', 'client']
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end

    it "sets database specific OT tags" do
      # TODO: Once we add support for regex matchers in tracing-matchers
      #       there will be no need for the ugly hack.
      #       See: https://github.com/iaintshine/ruby-tracing-matchers/issues/15
      sql = if Gem::Version.new(Rails.version) < Gem::Version.new("4.0.0")
              'SELECT COUNT(*) FROM "articles" '
            else
              'SELECT COUNT(*) FROM "articles"'
            end
      [
        ['db.type', 'sql'],
        ['db.vendor', 'sqlite3'],
        ['db.statement', sql],
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end
  end
end
