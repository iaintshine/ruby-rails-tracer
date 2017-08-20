require "spec_helper"
require "dalli"
require "active_support/cache/dalli_store"
require "rails/active_support/cache/dalli_tracer"

RSpec.describe Dalli::Tracer do
  let(:tracer) { Test::Tracer.new }
  let(:root_span) { tracer.start_span("root") }

  let(:hostname) { "localhost" }
  let(:port) { 11211 }
  let(:servers) { ["#{hostname}:#{port}"] }
  let(:cache) { ActiveSupport::Cache::DalliStore.new(servers) }
  let(:test_key) { "test-key" }

  describe "active span propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      Dalli::Tracer.instrument(tracer: tracer, active_span: -> { root_span })
      cache.read(test_key)
      root_span.finish
    end

    after do
      Dalli::Tracer.remove_instrumentation
    end

    it "creates spans for each part of the chain" do
      expect(tracer.finished_spans).not_to be_empty
      expect(tracer.finished_spans.size).to eq(3)
    end

    it "all spans contains the same trace_id" do
      tracer.finished_spans.each do |span|
        expect(span.context.trace_id).to eq(root_span.context.trace_id)
      end
    end

    it "propagates parent child relationship properly" do
      server_span = tracer.finished_spans[0]
      client_span = tracer.finished_spans[1]
      expect(server_span.context.parent_span_id).to eq(root_span.context.span_id)
      expect(client_span.context.parent_span_id).to eq(root_span.context.span_id)
    end
  end

  describe "auto-instrumentation" do
    before do
      Dalli::Tracer.instrument(tracer: tracer)
      cache.read(test_key)
    end

    after do
      Dalli::Tracer.remove_instrumentation
    end

    it "creates a new span" do
      expect(tracer.finished_spans).not_to be_empty
    end

    it "creates 2 spans, one for a server, and second for client" do
      expect(tracer.finished_spans.count).to eq(2)
    end

    describe "server span" do
      it "sets operation_name to ClassName#method" do
        expect(tracer.finished_spans.first.operation_name).to eq("Dalli::Server#request")
      end

      it "sets standard OT tags" do
        tags = tracer.finished_spans.first.tags
        [
          ['component', 'Dalli::Server'],
          ['span.kind', 'client']
        ].each do |key, value|
          expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got '#{tags[key]}'"
        end
      end

      it "sets cache specific OT tags" do
        tags = tracer.finished_spans.first.tags
        [
          ['db.statement', 'get'],
          ['db.type', 'memcached'],
          ['peer.hostname', hostname],
          ['peer.port', port],
          ['peer.weight', 1],
        ].each do |key, value|
          expect(tags[key]).to eq(value), "expected tag '#{key}' value to equal '#{value}', got #{tags[key]}"
        end
      end
    end

    describe "client span" do
      it "sets operation_name to ClassName#method" do
        expect(tracer.finished_spans.last.operation_name).to eq("Dalli::Client#perform")
      end
    end
  end
end
