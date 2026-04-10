Gem::Specification.new do |spec|
  spec.name          = "ses_dashboard"
  spec.version       = SesDashboard::VERSION rescue "0.1.0"
  spec.authors       = ["antodoms"]
  spec.email         = ["antodoms@outlook.com"]

  spec.summary       = "SES dashboard gem with pluggable authentication and AWS SES data fetching."
  spec.description   = "A mountable Rails engine that provides a real-time dashboard for Amazon SES, " \
                       "tracking email delivery, bounces, complaints, opens, and clicks via SNS webhooks."
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/antodoms/ses_dashboard"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/antodoms/ses_dashboard"
  spec.metadata["changelog_uri"]   = "https://github.com/antodoms/ses_dashboard/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*.rb"] +
      Dir["app/**/*"] +
      Dir["config/**/*"] +
      Dir["db/**/*"] +
      Dir["README.md"] +
      Dir["Rakefile"] +
      Dir["Dockerfile"] +
      Dir["docker-compose.yml"]
  end

  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "railties",      ">= 7.0"
  spec.add_dependency "activerecord",  ">= 7.0"
  spec.add_dependency "actionpack",    ">= 7.0"
  spec.add_dependency "actionview",    ">= 7.0"
  spec.add_dependency "aws-sdk-ses",   ">= 1.0"
  spec.add_dependency "rexml"  # required by aws-sdk-core XML parser; no longer default in Ruby 3.4+
  spec.add_dependency "csv"    # no longer a default gem in Ruby 3.4+

  # Development/test dependencies
  spec.add_development_dependency "bundler",                    ">= 2.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rspec-rails",               ">= 6.0"
  spec.add_development_dependency "rack-test"
  spec.add_development_dependency "rails",                     ">= 7.0"
  spec.add_development_dependency "sqlite3",                   ">= 2.1"
  spec.add_development_dependency "factory_bot_rails"
  spec.add_development_dependency "capybara"
  spec.add_development_dependency "rails-controller-testing"
  spec.add_development_dependency "puma"
  spec.add_development_dependency "selenium-webdriver"
  spec.add_development_dependency "database_cleaner-active_record"
end
