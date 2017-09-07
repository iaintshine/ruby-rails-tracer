require 'spec_helper'

RSpec.describe Rails::Tracer do
  describe "Class Methods" do
    it { should respond_to :instrument }
    it { should respond_to :disable }
  end

  describe :instrument do
    let(:tracer) { Test::Tracer.new }

    before do
      OpenTracing.global_tracer = tracer
    end

    context "default arguments" do
      it "doesn't instrument Rack" do
        expect(Rails::Rack::Tracer).not_to receive(:instrument)

        Rails::Tracer.instrument
      end

      it "instruments ActiveRecord" do
        expect(ActiveRecord::Tracer).to receive(:instrument)
          .with(tracer: tracer,
                active_span: nil)

        Rails::Tracer.instrument
      end

      it "instruments ActiveSupport::Cache" do
        expect(ActiveSupport::Cache::Tracer).to receive(:instrument)
          .with(tracer: tracer,
                active_span: nil,
                dalli: false)

        Rails::Tracer.instrument
      end
    end

    context "sub-tracers explicitly disabled" do
      it "doesn't instrument Rack" do
        expect(Rails::Rack::Tracer).not_to receive(:instrument)

        Rails::Tracer.instrument(rack: false)
      end

      it "doesn't instrument ActiveRecord" do
        expect(ActiveRecord::Tracer).not_to receive(:instrument)

        Rails::Tracer.instrument(active_record: false)
      end

      it "doesn't instrument ActiveSupport::Cache" do
        expect(ActiveSupport::Cache::Tracer).not_to receive(:instrument)

        Rails::Tracer.instrument(active_support_cache: false)
      end
    end

    context "sub-tracers explicitly enabled" do
      it "instruments Rack" do
        expect(Rails::Rack::Tracer).to receive(:instrument)
          .with(tracer: tracer,
                middlewares: Rails.configuration.middleware)

        Rails::Tracer.instrument(rack: true)
      end
    end

    describe "passing arguments to sub-tracers" do
      it "pass middlewares argument to rack tracer" do
        stack = double
        expect(Rails::Rack::Tracer).to receive(:instrument)
          .with(tracer: tracer,
                middlewares: stack)

        Rails::Tracer.instrument(rack: true, middlewares: stack)
      end

      it "pass dalli argument to cache tracer" do
        [true, false].each do |enabled|
          expect(ActiveSupport::Cache::Tracer).to receive(:instrument)
            .with(tracer: tracer,
                  active_span: nil,
                  dalli: enabled)

          Rails::Tracer.instrument(dalli: enabled)
        end
      end
    end
  end

  describe :disable do
    it "disables all submodules" do
      [
        Rails::Rack::Tracer,
        ActiveRecord::Tracer,
        ActiveSupport::Cache::Tracer
      ].each do |tracer_class|
        expect(tracer_class).to receive(:disable)
      end

      Rails::Tracer.disable
    end
  end
end
