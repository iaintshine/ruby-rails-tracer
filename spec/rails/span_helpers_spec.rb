require 'spec_helper'

RSpec.describe Rails::Tracer::SpanHelpers do
  describe "Class Methods" do
    it { should respond_to :set_error }
  end

  describe :set_error do
    let(:tracer) { Test::Tracer.new }
    let(:span) { tracer.start_span("failed span") }
    let(:exception) { Exception.new("test exception") }

    before do
      Rails::Tracer::SpanHelpers.set_error(span, exception)
    end

    it 'marks the span as failed' do
      expect(span).to have_tag('error', true)
    end

    it 'logs the error' do
      expect(span).to have_log(event: 'error', :'error.object' => exception)
    end

  end
end
