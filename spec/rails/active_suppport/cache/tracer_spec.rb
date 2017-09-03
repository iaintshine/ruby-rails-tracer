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
      expect(tracer).to have_traces(1)
    end

    it "creates the new span with active span as a parent" do
      cache_span = tracer.finished_spans.last
      expect(cache_span).to be_child_of(root_span)
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
        exception = Timeout::Error.new
        expect { Rails.cache.fetch(test_key) { raise exception } }.to raise_error(exception)
        expect(tracer).to have_span
          .with_tag('error', true)
          .with_log(event: 'error', :'error.object' => exception)
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
