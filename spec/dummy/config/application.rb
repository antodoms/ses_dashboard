require "rails"
require "active_record/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "propshaft"
require "ses_dashboard"
require "ses_dashboard/engine"

module Dummy
  class Application < Rails::Application
    config.root = File.expand_path("../..", __FILE__)
    config.load_defaults 8.0
    config.eager_load = false
    config.logger = Logger.new(nil)  # suppress output during tests
  end
end
