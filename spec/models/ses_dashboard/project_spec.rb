require "rails_helper"

RSpec.describe SesDashboard::Project, type: :model do
  describe "validations" do
    it "requires a name" do
      project = described_class.new(name: "")
      expect(project).not_to be_valid
      expect(project.errors[:name]).to include("can't be blank")
    end

    it "requires a unique token" do
      existing = create(:ses_dashboard_project)
      project  = described_class.new(name: "Other", token: existing.token)
      expect(project).not_to be_valid
    end
  end

  describe "token generation" do
    it "auto-generates a token on create" do
      project = described_class.create!(name: "Test")
      expect(project.token).to be_present
      expect(project.token.length).to eq(32)
    end

    it "does not overwrite an existing token" do
      project = described_class.create!(name: "Test", token: "my-custom-token")
      expect(project.reload.token).to eq("my-custom-token")
    end
  end

  describe "associations" do
    it "destroys associated emails when destroyed" do
      project = create(:ses_dashboard_project)
      create(:ses_dashboard_email, project: project)

      expect { project.destroy }.to change(SesDashboard::Email, :count).by(-1)
    end
  end
end
