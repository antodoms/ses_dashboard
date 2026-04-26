require "net/http"
require "uri"

module SesDashboard
  class WebhooksController < ApplicationController
    # Webhooks are authenticated by the project token in the URL, not by session auth.
    skip_before_action :authenticate!
    skip_before_action :verify_authenticity_token

    def create
      project = Project.find_by!(token: params[:project_token])
      request.body.rewind
      body   = request.body.read
      sns    = parse_sns_json(body)

      verify_sns_signature!(sns) if sns && SesDashboard.configuration.verify_sns_signature

      result = WebhookProcessor.new(body).process

      case result.action
      when :confirm_subscription
        confirm_subscription(result.subscribe_url)
      when :process_event
        WebhookEventPersistor.new(project, result).persist
        WebhookForwarder.new(project, result).forward
      end

      head :ok
    rescue ActiveRecord::RecordNotFound
      head :not_found
    rescue SnsSignatureVerifier::VerificationError => e
      Rails.logger.warn("[SesDashboard] SNS signature rejected: #{e.message}") if defined?(Rails)
      head :forbidden
    rescue => e
      Rails.logger.error("[SesDashboard] Webhook error: #{e.message}") if defined?(Rails)
      head :unprocessable_entity
    end

    private

    def confirm_subscription(url)
      Net::HTTP.get(URI(url))
    rescue => e
      Rails.logger.warn("[SesDashboard] SNS subscription confirm failed: #{e.message}") if defined?(Rails)
    end

    def parse_sns_json(body)
      JSON.parse(body)
    rescue JSON::ParserError
      nil
    end

    def verify_sns_signature!(sns)
      # Skip verification for raw delivery — no SNS envelope means no signature fields.
      return unless sns&.key?("SigningCertURL")

      SnsSignatureVerifier.new(sns).verify!
    end
  end
end
