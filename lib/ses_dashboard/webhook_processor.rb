require "json"
require "net/http"
require "uri"

module SesDashboard
  # Parses a raw SNS HTTP POST body and returns a normalized Result.
  #
  # Usage:
  #   result = WebhookProcessor.new(request.body.read).process
  #   case result.action
  #   when :confirm_subscription
  #     Net::HTTP.get(URI(result.subscribe_url))
  #   when :process_event
  #     WebhookEventPersistor.new(project, result).persist
  #   end
  #
  class WebhookProcessor
    Result = Struct.new(
      :action,          # :confirm_subscription | :process_event | :unknown
      :subscribe_url,   # present when action == :confirm_subscription
      :event_type,      # "send" | "delivery" | "bounce" | "complaint" | "open" | "click" | "reject" | "rendering_failure"
      :message_id,      # SES messageId
      :destination,     # Array of recipient addresses
      :source,          # From: address
      :subject,         # Email subject (may be nil)
      :occurred_at,     # Time
      :raw_payload,     # The full parsed inner SES event Hash for storage
      keyword_init: true
    )

    def initialize(raw_body)
      @raw_body = raw_body
    end

    def process
      sns = parse_json(@raw_body)
      return unknown_result unless sns

      case sns["Type"]
      when "SubscriptionConfirmation"
        Result.new(action: :confirm_subscription, subscribe_url: sns["SubscribeURL"])
      when "Notification"
        process_notification(sns)
      else
        unknown_result
      end
    rescue => e
      Rails.logger.error("[SesDashboard] WebhookProcessor error: #{e.message}") if defined?(Rails)
      unknown_result
    end

    private

    def process_notification(sns)
      message = parse_json(sns["Message"])
      return unknown_result unless message

      # SES supports two notification formats:
      # - Event Publishing (newer): uses "eventType" key
      # - Feedback Notifications (legacy): uses "notificationType" key
      raw_event_type = (message["eventType"] || message["notificationType"] || "").downcase
      event_type = normalize_event_type(raw_event_type)

      mail      = message["mail"] || {}
      timestamp = parse_time(mail["timestamp"] || sns["Timestamp"])

      Result.new(
        action:      :process_event,
        event_type:  event_type,
        message_id:  mail["messageId"],
        destination: Array(mail["destination"]),
        source:      mail["source"],
        subject:     extract_subject(mail),
        occurred_at: timestamp,
        raw_payload: message
      )
    end

    def normalize_event_type(raw)
      case raw
      when "send"              then "send"
      when "delivery"          then "delivery"
      when "bounce"            then "bounce"
      when "complaint"         then "complaint"
      when "open"              then "open"
      when "click"             then "click"
      when "reject"            then "reject"
      when "renderingfailure"  then "rendering_failure"
      else raw
      end
    end

    def extract_subject(mail)
      headers = Array(mail["headers"])
      subj    = headers.find { |h| h["name"]&.casecmp("subject")&.zero? }
      subj ? subj["value"] : (mail["commonHeaders"] || {})["subject"]
    end

    def parse_time(str)
      return Time.now.utc unless str
      Time.parse(str).utc
    rescue ArgumentError
      Time.now.utc
    end

    def parse_json(str)
      JSON.parse(str)
    rescue JSON::ParserError, TypeError
      nil
    end

    def unknown_result
      Result.new(action: :unknown)
    end
  end
end
