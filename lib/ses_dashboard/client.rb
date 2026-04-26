require "aws-sdk-ses"

module SesDashboard
  class Client
    def initialize(options = {})
      @options    = options.dup
      @ses_client = build_ses_client
      @cache      = {}
    end

    # ── SES monitoring API calls ─────────────────────────────────────────

    def send_quota
      cached(:send_quota) { ses_client.get_send_quota }
    end

    # Returns send data points from the last 14 days.
    # The SES v1 API accepts no date parameters — it always returns the last 14 days.
    def send_statistics
      cached(:send_statistics) { ses_client.get_send_statistics }
    end

    def list_identities
      cached(:identities) { ses_client.list_identities(types: ["EmailAddress", "Domain"]) }
    end

    def get_identity_verification_attributes(identities)
      cached(:verification_attributes, identities.sort.join(",")) do
        ses_client.get_identity_verification_attributes(identities: Array(identities))
      end
    end

    def get_identity_dkim_attributes(identities)
      cached(:dkim_attributes, identities.sort.join(",")) do
        ses_client.get_identity_dkim_attributes(identities: Array(identities))
      end
    end

    # ── Email sending ─────────────────────────────────────────────────────

    # Sends a plain-text email via SES SendEmail API.
    # Options: from:, to:, subject:, body:, configuration_set: (optional)
    def send_email(from:, to:, subject:, body:, configuration_set: nil)
      params = {
        source:      from,
        destination: { to_addresses: [to] },
        message:     {
          subject: { data: subject, charset: "UTF-8" },
          body:    { text: { data: body, charset: "UTF-8" } }
        }
      }
      params[:configuration_set_name] = configuration_set if configuration_set
      ses_client.send_email(params)
    end

    private

    attr_reader :ses_client, :options

    def build_ses_client
      # Only set region and stub_responses by default; let the AWS SDK credential
      # chain handle auth (SSO, IAM roles, instance profiles, env vars, etc.).
      # Explicit credentials can be supplied via options or configuration for
      # cases like CI where a static key pair is used.
      params = {
        region:        options[:region] || SesDashboard.configuration&.aws_region,
        stub_responses: options.fetch(:stub_responses, false)
      }

      config      = SesDashboard.configuration
      access_key  = options[:access_key_id]     || config&.aws_access_key_id
      secret_key  = options[:secret_access_key] || config&.aws_secret_access_key
      endpoint    = options[:endpoint]           || config&.endpoint

      params[:access_key_id]     = access_key if access_key
      params[:secret_access_key] = secret_key if secret_key
      params[:endpoint]          = endpoint   if endpoint

      Aws::SES::Client.new(params)
    end

    def cached(key, *context)
      return yield unless enable_cache?

      cache_key = [key, context].flatten.compact.join("-")
      return @cache[cache_key] if @cache.key?(cache_key)

      @cache[cache_key] = yield
    end

    def enable_cache?
      options.fetch(:cache_enabled, SesDashboard.configuration&.cache_enabled != false)
    end
  end
end
