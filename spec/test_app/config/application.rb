require_relative 'boot'

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_record/railtie"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_view/railtie"

if Gem::Version.new(Rails.version) >= Gem::Version.new("4.2.0")
  require "active_job/railtie"
end


if Gem::Version.new(Rails.version) >= Gem::Version.new("5.0.0")
  require "action_cable/engine"
end
# require "sprockets/railtie"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module TestApp
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    if Gem::Version.new(Rails.version) >= Gem::Version.new("5.1.0")
      config.load_defaults Rails.version[/(\d\.\d)/, 0]
    end

    # Settings in config/environments/* take precedence over those specified here.
    # Application configuration should go into files in config/initializers
    # -- all .rb files in that directory are automatically loaded.

    # Don't generate system test files.
    config.generators.system_tests = nil
  end
end
