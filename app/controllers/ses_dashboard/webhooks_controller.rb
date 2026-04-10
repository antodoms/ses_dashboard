require "net/http"
require "uri"

module SesDashboard
  class WebhooksController < ApplicationController
    # Webhooks are authenticated by the project token in the URL, not by session auth.
    skip_before_action :authenticate!
    skip_before_action :verify_authenticity_token

    def create
      project = Project.find_by!(token: params[:project_token])
      body    = request.body.read

      result = WebhookProcessor.new(body).process

      case result.action
      when :confirm_subscription
        confirm_subscription(result.subscribe_url)
      when :process_event
        WebhookEventPersistor.new(project, result).persist
      end

      head :ok
    rescue ActiveRecord::RecordNotFound
      head :not_found
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
  end
end
