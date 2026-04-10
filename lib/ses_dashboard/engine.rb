require "rails"
require "active_record"
require "action_controller"
require "action_view"

module SesDashboard
  class Engine < ::Rails::Engine
    isolate_namespace SesDashboard

    config.generators do |g|
      g.test_framework :rspec
      g.assets false
      g.helper false
    end

    # Make engine migrations available to the host app via `rails ses_dashboard:install:migrations`
    initializer "ses_dashboard.add_migrations" do |app|
      unless app.root.to_s == root.to_s
        app.config.paths["db/migrate"] += config.paths["db/migrate"].to_a
      end
    end

    # Precompile engine assets
    initializer "ses_dashboard.assets" do |app|
      if app.config.respond_to?(:assets)
        app.config.assets.precompile += %w[
          ses_dashboard/application.css
          ses_dashboard/application.js
        ]
      end
    end

    # Expose the engine's helpers to its own views
    config.to_prepare do
      SesDashboard::ApplicationController.helper(SesDashboard::ApplicationHelper) if
        defined?(SesDashboard::ApplicationController)
    end
  end
end
