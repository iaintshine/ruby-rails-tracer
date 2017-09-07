require "spec_helper"
require "rack/tracer"
require "rack/mock"

RSpec.describe Rails::Rack::Tracer do
  let(:tracer) { Test::Tracer.new }
  let(:env) { Rack::MockRequest.env_for('/api/user', method: 'GET') }
  let(:response) { [200, {'Content-Type' => 'application/json'}, ['{"users": []}']] }

  describe "Class Methods" do
    subject { described_class }

    it { should respond_to :instrument }
    it { should respond_to :disable }
  end

  describe :instrument do
    let(:stack) { ActionDispatch::MiddlewareStack.new }

    context "Rack::Tracer already present" do
      before do
        stack.use(::Rack::Tracer)
        Rails::Rack::Tracer.instrument(middlewares: stack)
      end

      it "does not insert additional Rack::Tracer" do
        rack_tracers = stack.middlewares.select { |m| m == ::Rack::Tracer }
        expect(rack_tracers.size).to eq(1)
      end

      it "inserts the tracer after Rack::Tracer" do
        rack_tracer = stack.middlewares.find_index(::Rack::Tracer)
        rails_tracer = stack.middlewares.find_index(Rails::Rack::Tracer)

        expect(rack_tracer).not_to be_nil
        expect(rails_tracer).not_to be_nil

        expect(rails_tracer).to be > rack_tracer
      end
    end

    context "Rack::Tracer wasn't present" do
      before do
        Rails::Rack::Tracer.instrument(middlewares: stack)
      end

      it "inserts additional Rack::Tracer" do
        rack_tracers = stack.middlewares.select { |m| m == ::Rack::Tracer }
        expect(rack_tracers.size).to eq(1)
      end

      it "inserts the tracer after Rack::Tracer" do
        rack_tracer = stack.middlewares.find_index(::Rack::Tracer)
        rails_tracer = stack.middlewares.find_index(Rails::Rack::Tracer)

        expect(rack_tracer).not_to be_nil
        expect(rails_tracer).not_to be_nil

        expect(rails_tracer).to be > rack_tracer
      end
    end
  end

  describe :disable do
    let(:stack) { ActionDispatch::MiddlewareStack.new }

    context "Rack::Tracer already present" do
      before do
        stack.use(::Rack::Tracer)
        Rails::Rack::Tracer.instrument(middlewares: stack)
        Rails::Rack::Tracer.disable(middlewares: stack)
      end

      it "leaves Rack::Tracer intact" do
        expect(stack.middlewares).to include(::Rack::Tracer)
      end

      it "removes rails tracer" do
        expect(stack.middlewares).not_to include(Rails::Rack::Tracer)
      end
    end

    context "Rack::Tracer wasn't present" do
      before do
        Rails::Rack::Tracer.instrument(middlewares: stack)
        Rails::Rack::Tracer.disable(middlewares: stack)
      end

      it "removes Rack::Tracer" do
        expect(stack.middlewares).not_to include(::Rack::Tracer)
      end

      it "removes rails tracer" do
        expect(stack.middlewares).not_to include(Rails::Rack::Tracer)
      end
    end
  end

  def respond_with(&app)
    enhance_middleware = Rails::Rack::Tracer.new(app)
    middleware = Rack::Tracer.new(enhance_middleware, tracer: tracer)
    middleware.call(env)
  end

  context 'when path was not found' do
    it 'leaves the operation_name as it was' do
      respond_with { response }

      expect(tracer).to have_spans(1)
      expect(tracer).to have_span('GET').finished
    end
  end

  context 'when path was found' do
    it 'enhances the operation_name to Controller#action' do
      respond_with do |env|
        env["action_dispatch.request.path_parameters"] = {controller: "/api/users", action: "index"}
        env["action_controller.instance"] = Api::UsersController.new
        response
      end

      expect(tracer).to have_spans(1)
      expect(tracer).to have_span('Api::UsersController#index').finished
    end
  end

  module Api
    class UsersController
    end
  end
end
