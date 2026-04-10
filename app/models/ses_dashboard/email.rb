module SesDashboard
  class Email < ApplicationRecord
    self.table_name = "ses_dashboard_emails"

    belongs_to :project, class_name: "SesDashboard::Project"
    has_many   :email_events, class_name: "SesDashboard::EmailEvent", dependent: :destroy

    # destination is a JSON-encoded array of recipient addresses
    serialize :destination, coder: JSON

    STATUSES = %w[sent delivered bounced complained rejected failed].freeze

    validates :message_id,  presence: true, uniqueness: true
    validates :source,      presence: true
    validates :destination, presence: true
    validates :status,      inclusion: { in: STATUSES }

    scope :by_project,    ->(project_id) { where(project_id: project_id) }
    scope :in_date_range, ->(from, to)   { where(sent_at: from..to) if from && to }
    scope :by_status,     ->(status)     { where(status: status) if status.present? }
    scope :ordered,       -> { order(sent_at: :desc, created_at: :desc) }

    scope :search, ->(query) {
      return all unless query.present?
      term = "%#{sanitize_sql_like(query)}%"
      where("source LIKE :q OR subject LIKE :q OR destination LIKE :q", q: term)
    }

    # State-machine transitions applied when SNS events arrive.
    # Only advance; never move backward (e.g., a late delivery event doesn't
    # overwrite a bounce).
    TRANSITIONS = {
      "sent"       => %w[delivered bounced complained rejected failed],
      "delivered"  => %w[complained],
      "bounced"    => [],
      "complained" => [],
      "rejected"   => [],
      "failed"     => []
    }.freeze

    def apply_status!(new_status)
      return if status == new_status
      return unless TRANSITIONS.fetch(status, []).include?(new_status)

      update_column(:status, new_status)
    end
  end
end
