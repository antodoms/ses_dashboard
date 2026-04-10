module SesDashboard
  class EmailEvent < ApplicationRecord
    self.table_name = "ses_dashboard_email_events"

    belongs_to :email, class_name: "SesDashboard::Email"

    serialize :event_data, coder: JSON

    EVENT_TYPES = %w[
      send delivery bounce complaint open click reject rendering_failure
    ].freeze

    validates :event_type,  inclusion: { in: EVENT_TYPES }
    validates :occurred_at, presence: true

    scope :ordered, -> { order(occurred_at: :asc) }
  end
end
