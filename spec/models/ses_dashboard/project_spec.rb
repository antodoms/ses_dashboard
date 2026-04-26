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

  describe "#webhook_forwards_text" do
    it "returns empty string when webhook_forwards is blank" do
      project = described_class.new(name: "Test")
      expect(project.webhook_forwards_text).to eq("")
    end

    it "returns pretty-printed JSON when forwards are set" do
      project = described_class.new(name: "Test")
      project.webhook_forwards = [{ "url" => "https://example.com", "event_types" => ["bounce"] }]
      expect(JSON.parse(project.webhook_forwards_text)).to eq(
        [{ "url" => "https://example.com", "event_types" => ["bounce"] }]
      )
    end
  end

  describe "#webhook_forwards_text=" do
    it "parses valid JSON into webhook_forwards" do
      project = described_class.new(name: "Test")
      project.webhook_forwards_text = '[{"url":"https://example.com","event_types":["bounce"]}]'
      expect(project.webhook_forwards).to eq([{ "url" => "https://example.com", "event_types" => ["bounce"] }])
    end

    it "sets webhook_forwards to [] when blank" do
      project = described_class.new(name: "Test")
      project.webhook_forwards_text = ""
      expect(project.webhook_forwards).to eq([])
    end

    it "adds a validation error for invalid JSON" do
      project = described_class.new(name: "Test")
      project.webhook_forwards_text = "not json"
      expect(project).not_to be_valid
      expect(project.errors[:webhook_forwards]).to include("is not valid JSON")
    end
  end

  describe "#effective_webhook_forwards" do
    around do |example|
      SesDashboard.reset_configuration!
      example.run
      SesDashboard.reset_configuration!
    end

    it "returns project-level forwards when configured" do
      project = described_class.new(name: "Test")
      project.webhook_forwards = [{ "url" => "https://project.example.com", "event_types" => ["bounce"] }]
      expect(project.effective_webhook_forwards).to eq(
        [{ "url" => "https://project.example.com", "event_types" => ["bounce"] }]
      )
    end

    it "falls back to global config when project has no forwards" do
      SesDashboard.configure do |c|
        c.webhook_forwards = [{ url: "https://global.example.com" }]
      end
      project = described_class.new(name: "Test")
      expect(project.effective_webhook_forwards).to eq([{ url: "https://global.example.com" }])
    end

    it "prefers project-level over global config" do
      SesDashboard.configure do |c|
        c.webhook_forwards = [{ url: "https://global.example.com" }]
      end
      project = described_class.new(name: "Test")
      project.webhook_forwards = [{ "url" => "https://project.example.com" }]
      forwards = project.effective_webhook_forwards
      expect(forwards.map { |f| f["url"] || f[:url] }).to eq(["https://project.example.com"])
    end

    it "returns empty array when neither project nor global has forwards" do
      project = described_class.new(name: "Test")
      expect(project.effective_webhook_forwards).to eq([])
    end
  end
end
