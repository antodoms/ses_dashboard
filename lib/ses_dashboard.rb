module SesDashboard
  class Error < StandardError; end

  class << self
    attr_accessor :configuration
  end

  def self.configure
    self.configuration ||= Configuration.new
    yield(configuration) if block_given?
  end

  def self.reset_configuration!
    self.configuration = Configuration.new
  end

  class Configuration
    # AWS — credentials are optional. The SDK credential chain (SSO, IAM roles, instance
    # profiles, env vars) is used when these are not explicitly set.
    attr_accessor :aws_region, :aws_access_key_id, :aws_secret_access_key, :endpoint

    # Auth — :none, :devise, :cloudflare, or any object responding to #authenticate(request)
    attr_accessor :authentication_adapter

    # Caching for SES API calls (quota, statistics, etc.)
    attr_accessor :cache_enabled

    # Dashboard behaviour
    attr_accessor :per_page            # rows per page in activity log (default 25)
    attr_accessor :time_zone           # time zone for chart grouping (default "UTC")
    attr_accessor :test_email_from     # From: address used when sending test emails

    # Security — set to true in production to validate SNS message signatures
    attr_accessor :verify_sns_signature

    # Cloudflare Zero Trust
    attr_accessor :cloudflare_team_domain  # e.g. "myteam.cloudflareaccess.com"
    attr_accessor :cloudflare_aud          # JWT audience (your CF application AUD)

    def initialize
      @aws_region              = ENV.fetch("AWS_REGION", "us-east-1")
      @aws_access_key_id       = nil
      @aws_secret_access_key   = nil
      @endpoint                = ENV["AWS_ENDPOINT_URL"]  # LocalStack in dev/test
      @authentication_adapter  = :none
      @cache_enabled           = true
      @per_page                = 25
      @time_zone               = "UTC"
      @test_email_from         = nil
      @verify_sns_signature    = false
      @cloudflare_team_domain  = nil
      @cloudflare_aud          = nil
    end
  end
end

require_relative "ses_dashboard/version"
require_relative "ses_dashboard/client"
require_relative "ses_dashboard/webhook_processor"
require_relative "ses_dashboard/sns_signature_verifier"
require_relative "ses_dashboard/stats_aggregator"
require_relative "ses_dashboard/paginatable"
require_relative "ses_dashboard/auth/base"
require_relative "ses_dashboard/auth/devise_adapter"
require_relative "ses_dashboard/auth/cloudflare_adapter"
require "ses_dashboard/engine"
