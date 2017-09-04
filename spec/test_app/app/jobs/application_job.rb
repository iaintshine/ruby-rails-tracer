if Gem::Version.new(Rails.version) >= Gem::Version.new("4.2.0")
  class ApplicationJob < ActiveJob::Base
  end
end
