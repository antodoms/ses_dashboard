ENV["RAILS_ENV"] ||= "test"

# Set DATABASE_URL before loading the Rails environment so ActiveRecord never
# tries to find config/database.yml relative to the working directory.
ENV["DATABASE_URL"] = "sqlite3::memory:"

require File.expand_path("dummy/config/environment", __dir__)

# Force all routes (including engine routes) to be drawn after initialization.
# Without this, SesDashboard::Engine.routes is empty when controller specs run.
Rails.application.reload_routes!

require "rspec/rails"
require "factory_bot_rails"
require_relative "support/aws_mocks"

# Establish the in-memory connection and run engine migrations once per suite.
# We call each migration's #change directly rather than going through
# MigrationContext — that API changed in Rails 8 and we don't need schema
# version tracking in an in-memory test database.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false

load File.expand_path("../db/migrate/20240101000001_create_ses_dashboard_projects.rb", __dir__)
load File.expand_path("../db/migrate/20240101000002_create_ses_dashboard_emails.rb", __dir__)
load File.expand_path("../db/migrate/20240101000003_create_ses_dashboard_email_events.rb", __dir__)

ActiveRecord::Migration.suppress_messages do
  CreateSesDashboardProjects.new.change
  CreateSesDashboardEmails.new.change
  CreateSesDashboardEmailEvents.new.change
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Rails.application.routes.url_helpers
  config.include SesDashboard::Engine.routes.url_helpers

  config.use_transactional_fixtures = true

  config.before(:each) do
    SesDashboard.reset_configuration!
  end

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
