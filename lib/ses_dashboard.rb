require_relative "ses_dashboard/version"
require_relative "ses_dashboard/client"
require_relative "ses_dashboard/auth/base"
require_relative "ses_dashboard/auth/devise_adapter"

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
    # Credentials are optional — the AWS SDK credential chain (SSO, IAM roles,
    # instance profiles, env vars) is used when these are not set.
    attr_accessor :aws_region, :aws_access_key_id, :aws_secret_access_key,
                  :endpoint, :authentication_adapter, :cache_enabled

    def initialize
      @aws_region = ENV.fetch("AWS_REGION", "us-east-1")
      @aws_access_key_id = nil
      @aws_secret_access_key = nil
      @endpoint = ENV["AWS_ENDPOINT_URL"]  # useful for LocalStack in dev/test
      @authentication_adapter = :none
      @cache_enabled = true
    end
  end

  autoload :Engine, "ses_dashboard/engine"
end
