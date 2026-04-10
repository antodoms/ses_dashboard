module SesDashboard
  # Persists a processed SNS event (from WebhookProcessor::Result) to the database.
  #
  # Separating parsing (WebhookProcessor, in lib/) from persistence (here) keeps
  # the parser free of Rails/AR dependencies and fully unit-testable.
  #
  class WebhookEventPersistor
    def initialize(project, result)
      @project = project
      @result  = result
    end

    def persist
      return if @result.message_id.blank?

      ActiveRecord::Base.transaction do
        email = find_or_create_email
        create_event(email)
        update_email_state(email)
      end
    rescue ActiveRecord::RecordInvalid => e
      log_error("Failed to persist webhook event: #{e.message}")
    end

    private

    def find_or_create_email
      Email.find_or_initialize_by(message_id: @result.message_id) do |e|
        e.project     = @project
        e.destination = @result.destination
        e.source      = @result.source
        e.subject     = @result.subject
        e.sent_at     = @result.occurred_at
        e.status      = "sent"
      end.tap(&:save!)
    end

    def create_event(email)
      email.email_events.create!(
        event_type:  @result.event_type,
        event_data:  @result.raw_payload,
        occurred_at: @result.occurred_at
      )
    end

    def update_email_state(email)
      case @result.event_type
      when "delivery"
        email.apply_status!("delivered")
      when "bounce"
        email.apply_status!("bounced")
      when "complaint"
        email.apply_status!("complained")
      when "reject"
        email.apply_status!("rejected")
      when "rendering_failure"
        email.apply_status!("failed")
      when "open"
        Email.update_counters(email.id, opens: 1)
      when "click"
        Email.update_counters(email.id, clicks: 1)
      end
    end

    def log_error(msg)
      defined?(Rails) ? Rails.logger.error("[SesDashboard] #{msg}") : nil
    end
  end
end
