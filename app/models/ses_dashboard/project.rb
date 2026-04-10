module SesDashboard
  class Project < ApplicationRecord
    self.table_name = "ses_dashboard_projects"

    has_many :emails, class_name: "SesDashboard::Email", dependent: :destroy

    validates :name,  presence: true
    validates :token, presence: true, uniqueness: true

    before_validation :generate_token, on: :create

    scope :ordered, -> { order(:name) }

    private

    def generate_token
      self.token ||= SecureRandom.hex(16)
    end
  end
end
