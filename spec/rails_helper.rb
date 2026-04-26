ENV["RAILS_ENV"] ||= "test"

# Use a file-based SQLite database so the Puma server thread (used by Capybara
# system specs) shares the same data as the test thread.
# In-memory SQLite gives each connection its own isolated database.
require "fileutils"
db_file = File.expand_path("tmp/test.db", __dir__)
FileUtils.mkdir_p(File.dirname(db_file))
File.delete(db_file) if File.exist?(db_file)
ENV["DATABASE_URL"] = "sqlite3:#{db_file}"

require File.expand_path("dummy/config/environment", __dir__)

# Force all routes (including engine routes) to be drawn after initialization.
Rails.application.reload_routes!

require "rspec/rails"
require "factory_bot_rails"
require "database_cleaner/active_record"
require_relative "support/aws_mocks"
require_relative "support/capybara"

# Build the schema directly from engine migrations — avoids MigrationContext
# API differences across Rails versions and works with in-memory / file DBs.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: db_file)
ActiveRecord::Schema.verbose = false

load File.expand_path("../db/migrate/20240101000001_create_ses_dashboard_projects.rb", __dir__)
load File.expand_path("../db/migrate/20240101000002_create_ses_dashboard_emails.rb", __dir__)
load File.expand_path("../db/migrate/20240101000003_create_ses_dashboard_email_events.rb", __dir__)
load File.expand_path("../db/migrate/20240101000004_add_webhook_forwards_to_ses_dashboard_projects.rb", __dir__)

ActiveRecord::Migration.suppress_messages do
  CreateSesDashboardProjects.new.change
  CreateSesDashboardEmails.new.change
  CreateSesDashboardEmailEvents.new.change
  AddWebhookForwardsToSesDashboardProjects.new.change
end

RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
  config.include Rails.application.routes.url_helpers
  config.include SesDashboard::Engine.routes.url_helpers

  # DatabaseCleaner manages transaction wrapping — disable RSpec's built-in.
  config.use_transactional_fixtures = false

  config.before(:suite) do
    DatabaseCleaner.clean_with(:truncation)
  end

  # Use the remote Chrome driver for every system spec.
  # We set current_driver directly rather than calling driven_by — driven_by
  # goes through Rails' ActionDispatch::SystemTestCase machinery which may not
  # boot the Capybara/Puma server for custom (non-built-in) drivers.
  config.before(:each, type: :system) do
    driven_by :remote_chrome
  end

  config.after(:each, type: :system) do
    Capybara.reset_sessions!
    Capybara.use_default_driver
  end

  config.before(:each) do |example|
    SesDashboard.reset_configuration!
    # System specs need truncation: the Puma server runs in a separate thread
    # with its own connection, so a transaction rollback won't clean its data.
    # All other specs use a transaction that is rolled back after each example.
    DatabaseCleaner.strategy = (example.metadata[:type] == :system) ? :truncation : :transaction
    DatabaseCleaner.start
  end

  config.after(:each) do
    DatabaseCleaner.clean
  end

  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
end
