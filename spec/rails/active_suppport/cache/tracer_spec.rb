require "spec_helper"
require "spanmanager"

RSpec.describe ActiveSupport::Cache::Tracer do
  let(:tracer) { Test::Tracer.new }
  let(:test_key) { "test-key" }

  describe "active span propagation" do
    let(:root_span) { tracer.start_span("root") }

    before do
      ActiveSupport::Cache::Tracer.instrument(tracer: tracer, active_span: -> { root_span })
      Rails.cache.read(test_key)
    end

    after do
      ActiveSupport::Cache::Tracer.disable
      Rails.cache.clear
    end

    it "creates the new span with active span trace_id" do
      expect(tracer).to have_traces(1)
    end

    it "creates the new span with active span as a parent" do
      cache_span = tracer.finished_spans.last
      expect(cache_span).to be_child_of(root_span)
    end
  end

  describe "nested context" do
    let(:test_tracer) { Test::Tracer.new }
    let(:tracer) { SpanManager::Tracer.new(test_tracer) }

    before do
      ActiveSupport::Cache::Tracer.instrument(tracer: tracer, active_span: -> { tracer.active_span })

      root = tracer.start_span("root")
        Rails.cache.fetch(test_key) do
          tracer.start_span("nested").finish
          "test-value"
        end
      root.finish
    end

    after do
      ActiveSupport::Cache::Tracer.disable
      Rails.cache.clear
    end

    it "creates a single trace" do
      expect(test_tracer).to have_traces(1)
    end

    it "creates 5 spans" do
      expect(test_tracer).to have_spans(5)
    end

    if Gem::Version.new(Rails.version) >= Gem::Version.new("4.0.0")
      it "creates nested spans tree" do
        expect(test_tracer).to have_span("root")
        expect(test_tracer).to have_span("cache.read").with_parent("root")
        expect(test_tracer).to have_span("cache.generate").with_parent("root")
        expect(test_tracer).to have_span("nested").with_parent("cache.generate")
        expect(test_tracer).to have_span("cache.write").with_parent("root")
      end
    else
      it "creates flat spans tree" do
        expect(test_tracer).to have_span("root")
        expect(test_tracer).to have_span("cache.read").with_parent("root")
        expect(test_tracer).to have_span("cache.generate").with_parent("root")
        expect(test_tracer).to have_span("nested").with_parent("root")
        expect(test_tracer).to have_span("cache.write").with_parent("root")
      end
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
      expect(tracer).to have_spans
    end

    it "sets operation_name to event's name" do
      expect(tracer).to have_span("cache.read")
    end

    it "sets standard OT tags" do
      [
        ['component', 'ActiveSupport::Cache'],
        ['span.kind', 'client']
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end

    it "sets cache specific OT tags" do
      [
        ['cache.key', test_key],
      ].each do |key, value|
        expect(tracer).to have_span.with_tag(key, value)
      end
    end

    context "cache entry not found during read" do
      it "sets cache.hit tag to false" do
        Rails.cache.read(test_key)
        expect(tracer).to have_span.with_tag('cache.hit', false)
      end
    end

    context "cache entry found during read" do
      it "sets cache.hit tag to true" do
        Rails.cache.write(test_key, "a value")
        Rails.cache.read(test_key)
        expect(tracer).to have_span.with_tag('cache.hit', false)
      end
    end

    context "exception thrown during cache operation" do
      it "sets error on span" do
        exception = Timeout::Error.new("couldn't reach cache server")
        expect { Rails.cache.fetch(test_key) { raise exception } }.to raise_error(exception)
        if Gem::Version.new(Rails.version) >= Gem::Version.new("5.0.0")
          # exception_object was introduced in Rails version 5+
          expect(tracer).to have_span
            .with_tag('error', true)
            .with_log(event: 'error', :'error.object' => exception)
        else
          expect(tracer).to have_span
            .with_tag('error', true)
            .with_log(event: 'error', :'error.kind' => "Timeout::Error", message: "couldn't reach cache server")
        end
      end
    end
  end

  describe "dalli store auto-instrumentation option" do
    def instrument(dalli:)
      cache_tracer = ActiveSupport::Cache::Tracer.instrument(tracer: tracer, active_span: -> { }, dalli: dalli)
      ActiveSupport::Notifications.unsubscribe(cache_tracer)
    end

    context "Dalli wasn't required" do
      context "dalli: false" do
        let(:enabled) { false }

        it "doesn't enable dalli auto-instrumentation" do
          expect(Dalli::Tracer).not_to receive(:instrument)
          instrument(dalli: enabled)
        end
      end

      context "dalli: true" do
        let(:enabled) { true }

        before do
          HiddenDalliStore = ActiveSupport::Cache::DalliStore
          ActiveSupport::Cache.send(:remove_const, "DalliStore")
        end

        after do
          ActiveSupport::Cache::DalliStore = HiddenDalliStore
        end

        it "doesn't enable dalli auto-instrumentation" do
          expect(Dalli::Tracer).not_to receive(:instrument)
          instrument(dalli: enabled)
        end
      end
    end

    context "Dalli was required" do
      context "dalli: false" do
        let(:enabled) { false }

        it "doesn't enable dalli auto-instrumentation" do
          expect(Dalli::Tracer).not_to receive(:instrument)
          instrument(dalli: enabled)
        end
      end

      context "dalli: true" do
        let(:enabled) { true }

        it "enables dalli auto-instrumentation" do
          expect(Dalli::Tracer).to receive(:instrument)
          instrument(dalli: enabled)
        end

        describe "Dalli tracing logger" do
          context "logger already instrumented" do
            it "keeps current logger intact" do
              logger = Tracing::Logger.new(active_span: -> { })
              Dalli.logger = logger
              instrument(dalli: enabled)
              expect(Dalli.logger).to eq(logger)

              logger = Tracing::CompositeLogger.new(logger)
              Dalli.logger = logger
              instrument(dalli: enabled)
              expect(Dalli.logger).to eq(logger)
            end
          end

          context "logger wasn't instrumented" do
            let(:stdout_logger) { Logger.new(STDOUT) }

            before do
              Dalli.logger = stdout_logger
              instrument(dalli: enabled)
            end

            it "creates composite logger" do
              expect(Dalli.logger).to be_instance_of(Tracing::CompositeLogger)
            end

            it "wraps existing logger" do
              expect(Dalli.logger.destinations).to include(stdout_logger)
            end

            it "wraps tracing logger with ERROR severity level" do
              logger = Dalli.logger.destinations.find { |d| d.is_a?(Tracing::Logger) }
              expect(logger).not_to be_nil
              expect(logger.level).to eq(Logger::ERROR)
            end
          end
        end
      end
    end
  end
end
