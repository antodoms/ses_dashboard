require "net/http"
require "uri"
require "json"

module SesDashboard
  # Forwards processed SES events to external webhook URLs based on configurable rules.
  #
  # Rules are resolved per-project (see Project#effective_webhook_forwards), with a
  # global fallback from SesDashboard.configuration.webhook_forwards.
  #
  # Each forward entry supports a `rules` array — all rules must match (AND logic).
  # If no rules are specified, every event is forwarded.
  #
  #   [
  #     {
  #       "url": "https://hooks.zapier.com/hooks/catch/abc/xyz/",
  #       "rules": [
  #         { "field": "event_type", "operator": "in", "value": ["bounce", "complaint"] },
  #         { "field": "source",     "operator": "ends_with", "value": "@myapp.com" }
  #       ]
  #     }
  #   ]
  #
  # Legacy shorthand `event_types` is still supported and auto-converted to a rule:
  #   { "url": "...", "event_types": ["bounce"] }
  #   ⟶ rules: [{ field: "event_type", operator: "in", value: ["bounce"] }]
  #
  class WebhookForwarder
    OPEN_TIMEOUT = 5  # seconds
    READ_TIMEOUT = 10 # seconds

    def initialize(project, result)
      @project = project
      @result  = result
    end

    def forward
      forwards = @project.effective_webhook_forwards
      return if forwards.empty?

      forwards.each do |config|
        url = config[:url] || config["url"]
        next if url.blank?
        next unless matches_rules?(config)

        post_to(url)
      rescue => e
        log_warn("Forward to #{url} failed: #{e.message}")
      end
    end

    private

    def matches_rules?(config)
      rules = resolve_rules(config)
      return true if rules.empty?

      rules.all? { |rule| ForwardRule.new(rule).match?(@result) }
    end

    # Supports both the new `rules` format and the legacy `event_types` shorthand.
    def resolve_rules(config)
      rules = Array(config["rules"] || config[:rules])
      return rules if rules.any?

      event_types = Array(config["event_types"] || config[:event_types])
      return [] if event_types.empty?

      [{ "field" => "event_type", "operator" => "in", "value" => event_types }]
    end

    def post_to(url)
      uri  = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl      = uri.scheme == "https"
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT

      req                  = Net::HTTP::Post.new(uri.request_uri)
      req["Content-Type"]  = "application/json"
      req.body             = build_payload

      response = http.request(req)
      unless response.is_a?(Net::HTTPSuccess)
        log_warn("Forward to #{url} returned HTTP #{response.code}")
      end
    end

    def build_payload
      {
        event_type:  @result.event_type,
        message_id:  @result.message_id,
        source:      @result.source,
        destination: @result.destination,
        subject:     @result.subject,
        occurred_at: @result.occurred_at&.iso8601,
        raw:         @result.raw_payload
      }.to_json
    end

    def log_warn(msg)
      Rails.logger.warn("[SesDashboard] #{msg}") if defined?(Rails)
    end
  end
end
