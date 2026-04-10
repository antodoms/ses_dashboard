require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  add_filter "/lib/ses_dashboard/version.rb"
  enable_coverage :branch
end

require "bundler/setup"
require "rspec"
require "aws-sdk-ses"
require "ses_dashboard"
require_relative "support/aws_mocks"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.before(:each) do
    SesDashboard.reset_configuration!
  end
end
