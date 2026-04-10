ENV["RAILS_ENV"] ||= "test"

require File.expand_path("dummy/config/environment", __dir__)
require "rspec/rails"
require "factory_bot_rails"
require_relative "support/aws_mocks"

# Run engine migrations against the in-memory SQLite database
ActiveRecord::Schema.verbose = false
load File.expand_path("../db/migrate/20240101000001_create_ses_dashboard_projects.rb", __dir__)
load File.expand_path("../db/migrate/20240101000002_create_ses_dashboard_emails.rb", __dir__)
load File.expand_path("../db/migrate/20240101000003_create_ses_dashboard_email_events.rb", __dir__)
CreateSesDashboardProjects.new.change
CreateSesDashboardEmails.new.change
CreateSesDashboardEmailEvents.new.change

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Rails.application.routes.url_helpers
  config.include SesDashboard::Engine.routes.url_helpers

  # Use transactional fixtures to roll back each example
  config.use_transactional_fixtures = true

  config.before(:suite) do
    FactoryBot.find_definitions
  end

  config.before(:each) do
    SesDashboard.reset_configuration!
  end

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
