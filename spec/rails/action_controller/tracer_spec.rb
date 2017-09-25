require "spec_helper"
require "rack/tracer"
require "rack/mock"

RSpec.describe ActionController::Tracer do
  include Rack::Test::Methods

  let(:tracer) { Test::Tracer.new }

  def app
    Rails.application
  end

  describe "active span propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      ActionController::Tracer.instrument(tracer: tracer, active_span: -> { root_span })
      get '/articles'
    end

    after do
      ActionController::Tracer.disable
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
      ActionController::Tracer.instrument(tracer: tracer)
      get '/articles'
    end

    after do
      ActionController::Tracer.disable
    end

    it "creates a new span" do
      expect(tracer).to have_spans
    end

    it "sets operation_name to currently executed controller and action" do
      expect(tracer).to have_span("ArticlesController#index")
    end

    it "sets standard OT tags" do
      [
        ['component', 'ActionController'],
        ['span.kind', 'server'],
        ['http.method', 'GET'],
        ['http.url', '/articles'],
        ['http.status_code', 200]
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end

    it "sets ActionController specific OT tags" do
      [
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end
  end
end
