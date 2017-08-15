require "spec_helper"
require "rack/tracer"
require "rack/mock"

RSpec.describe Rails::Rack::Tracer do
  let(:tracer) { Test::Tracer.new }
  let(:env) { Rack::MockRequest.env_for('/api/user', method: 'GET') }
  let(:response) { [200, {'Content-Type' => 'application/json'}, ['{"users": []}']] }

  def respond_with(&app)
    enhance_middleware = Rails::Rack::Tracer.new(app)
    middleware = Rack::Tracer.new(enhance_middleware, tracer: tracer)
    middleware.call(env)
  end

  context 'when path was not found' do
    it 'leaves the operation_name as it was' do
      respond_with { response }

      expect(tracer.finished_spans.first.operation_name).to eq('GET')
    end
  end

  context 'when path was found' do
    it 'enhances the operation_name to Controller#action' do
      respond_with do |env|
        env["action_dispatch.request.path_parameters"] = {controller: "/api/users", action: "index"}
        env["action_controller.instance"] = Api::UsersController.new
        response
      end

      expect(tracer.finished_spans.first.operation_name).to eq('Api::UsersController#index')
    end
  end

  module Api
    class UsersController
    end
  end
end
