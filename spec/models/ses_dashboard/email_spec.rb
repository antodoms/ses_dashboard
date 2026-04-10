require "rails_helper"

RSpec.describe SesDashboard::Email, type: :model do
  describe "validations" do
    it "is valid with required attributes" do
      email = build(:ses_dashboard_email)
      expect(email).to be_valid
    end

    it "requires message_id uniqueness" do
      existing = create(:ses_dashboard_email)
      duplicate = build(:ses_dashboard_email, message_id: existing.message_id)
      expect(duplicate).not_to be_valid
    end

    it "enforces valid status values" do
      email = build(:ses_dashboard_email, status: "unknown_status")
      expect(email).not_to be_valid
    end
  end

  describe "#apply_status!" do
    it "transitions from sent to delivered" do
      email = create(:ses_dashboard_email, status: "sent")
      email.apply_status!("delivered")
      expect(email.reload.status).to eq("delivered")
    end

    it "does not allow backward transitions" do
      email = create(:ses_dashboard_email, status: "delivered")
      email.apply_status!("sent")
      expect(email.reload.status).to eq("delivered")  # unchanged
    end

    it "does not overwrite a terminal bounce with delivery" do
      email = create(:ses_dashboard_email, status: "bounced")
      email.apply_status!("delivered")
      expect(email.reload.status).to eq("bounced")  # unchanged
    end
  end

  describe ".search" do
    it "matches on subject" do
      create(:ses_dashboard_email, subject: "Invoice #42")
      create(:ses_dashboard_email, subject: "Newsletter")

      results = described_class.search("Invoice")
      expect(results.map(&:subject)).to include("Invoice #42")
      expect(results.map(&:subject)).not_to include("Newsletter")
    end
  end

  describe "destination JSON serialisation" do
    it "stores and retrieves an array" do
      email = create(:ses_dashboard_email, destination: ["a@b.com", "c@d.com"])
      expect(email.reload.destination).to eq(["a@b.com", "c@d.com"])
    end
  end
end
