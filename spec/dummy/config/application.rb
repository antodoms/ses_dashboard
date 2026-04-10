require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "ses_dashboard"

module Dummy
  class Application < Rails::Application
    config.load_defaults 8.0
    config.eager_load = false
    config.logger = Logger.new(nil)  # suppress output during tests
  end
end
