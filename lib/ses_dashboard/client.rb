require "aws-sdk-ses"

module SesDashboard
  class Client
    CACHE_KEYS = %i[send_quota send_statistics identities verification_attributes dkim_attributes].freeze

    def initialize(options = {})
      @options = options.dup
      @ses_client = build_ses_client
      @cache = {}
    end

    def send_quota
      cached(:send_quota) do
        ses_client.get_send_quota
      end
    end

    # Returns send data points from the last 14 days (SES v1 API has no date filtering).
    def send_statistics
      cached(:send_statistics) do
        ses_client.get_send_statistics
      end
    end

    def list_identities
      cached(:identities) do
        ses_client.list_identities(types: ["EmailAddress", "Domain"])
      end
    end

    def get_identity_verification_attributes(identities)
      cached(:verification_attributes, identities.sort.join(",")) do
        ses_client.get_identity_verification_attributes({ identities: Array(identities) })
      end
    end

    def get_identity_dkim_attributes(identities)
      cached(:dkim_attributes, identities.sort.join(",")) do
        ses_client.get_identity_dkim_attributes({ identities: Array(identities) })
      end
    end

    private

    attr_reader :ses_client, :options

    def build_ses_client
      # Only set region and stub_responses by default; let the AWS SDK credential
      # chain handle auth (SSO, IAM roles, instance profiles, env vars, etc.).
      # Explicit credentials can be supplied via options or configuration for
      # cases like CI where a static key pair is used.
      params = {
        region: options[:region] || SesDashboard.configuration&.aws_region,
        stub_responses: options.fetch(:stub_responses, false)
      }

      config = SesDashboard.configuration
      access_key    = options[:access_key_id]    || config&.aws_access_key_id
      secret_key    = options[:secret_access_key] || config&.aws_secret_access_key
      endpoint      = options[:endpoint]          || config&.endpoint

      params[:access_key_id]     = access_key  if access_key
      params[:secret_access_key] = secret_key  if secret_key
      params[:endpoint]          = endpoint    if endpoint

      Aws::SES::Client.new(params)
    end

    def cached(key, *context)
      if enable_cache?
        cache_key = [key, context].flatten.compact.join("-")
        return @cache[cache_key] if @cache.key?(cache_key)
        @cache[cache_key] = yield
      else
        yield
      end
    end

    def enable_cache?
      options.fetch(:cache_enabled, SesDashboard.configuration&.cache_enabled != false)
    end
  end
end
