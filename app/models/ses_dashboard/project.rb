module SesDashboard
  class Project < ApplicationRecord
    self.table_name = "ses_dashboard_projects"

    has_many :emails, class_name: "SesDashboard::Email", dependent: :destroy

    validates :name,  presence: true
    validates :token, presence: true, uniqueness: true
    validate  :webhook_forwards_must_be_valid_json

    before_validation :generate_token, on: :create

    scope :ordered, -> { order(:name) }

    # Manual JSON serialization for the webhook_forwards column.
    # Avoids Rails serialize API which changed between 7.0 (positional)
    # and 8.0 (keyword-only coder:).
    def webhook_forwards
      raw = read_attribute(:webhook_forwards)
      return [] if raw.blank?
      return raw if raw.is_a?(Array)

      JSON.parse(raw)
    rescue JSON::ParserError
      []
    end

    def webhook_forwards=(value)
      write_attribute(:webhook_forwards, value.is_a?(String) ? value : Array(value).to_json)
    end

    # Virtual accessor for editing webhook_forwards as a JSON string in forms.
    def webhook_forwards_text
      forwards = Array(webhook_forwards)
      forwards.empty? ? "" : JSON.pretty_generate(forwards)
    end

    def webhook_forwards_text=(value)
      if value.blank?
        self.webhook_forwards = []
        return
      end

      parsed = JSON.parse(value)
      self.webhook_forwards = Array(parsed)
    rescue JSON::ParserError
      @webhook_forwards_invalid = true
    end

    # Returns the effective forwards: project-level if configured, else global config.
    def effective_webhook_forwards
      project_level = Array(webhook_forwards).select { |f| (f[:url] || f["url"]).present? }
      return project_level if project_level.any?

      Array(SesDashboard.configuration&.webhook_forwards)
    end

    private

    def generate_token
      self.token ||= SecureRandom.hex(16)
    end

    def webhook_forwards_must_be_valid_json
      errors.add(:webhook_forwards, "is not valid JSON") if @webhook_forwards_invalid
    end
  end
end
