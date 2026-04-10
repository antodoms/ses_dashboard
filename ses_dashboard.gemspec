Gem::Specification.new do |spec|
  spec.name          = "ses_dashboard"
  spec.version       = SesDashboard::VERSION rescue "0.1.0"
  spec.authors       = ["antodoms"]
  spec.email         = ["antodoms@outlook.com"]

  spec.summary       = "SES dashboard gem with pluggable authentication and AWS SES data fetching."
  spec.description   = "A reusable Ruby gem for rendering SES usage and identity dashboards with optional authentication adapters."
  spec.license       = "MIT"
  spec.homepage      = "https://github.com/antodoms/ses_dashboard"
  spec.required_ruby_version = ">= 3.0"

  spec.metadata["homepage_uri"]    = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/antodoms/ses_dashboard"
  spec.metadata["changelog_uri"]   = "https://github.com/antodoms/ses_dashboard/CHANGELOG.md"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["lib/**/*.rb"] + Dir["README.md"] + Dir["Rakefile"] + Dir["Dockerfile"] + Dir["docker-compose.yml"]
  end

  spec.require_paths = ["lib"]

  spec.add_dependency "aws-sdk-ses", ">= 1.0"
  spec.add_dependency "rack", ">= 2.0"
  spec.add_dependency "rexml"  # required by aws-sdk-core XML parser; no longer a default gem in Ruby 3.4+

  spec.add_development_dependency "bundler", ">= 2.0"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rack-test"
end
