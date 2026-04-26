require "spec_helper"
require "ses_dashboard"

RSpec.describe SesDashboard::ForwardRule do
  let(:result) do
    SesDashboard::WebhookProcessor::Result.new(
      action:      :process_event,
      event_type:  "bounce",
      message_id:  "msg-abc123",
      source:      "noreply@myapp.com",
      destination: ["alice@example.com", "bob@test.org"],
      subject:     "Your invoice #1234",
      occurred_at: Time.utc(2024, 1, 15, 10, 0, 0),
      raw_payload: { "eventType" => "Bounce" }
    )
  end

  def rule(field:, operator:, value:)
    described_class.new("field" => field, "operator" => operator, "value" => value)
  end

  describe "event_type field" do
    it "matches with 'in' operator" do
      expect(rule(field: "event_type", operator: "in", value: ["bounce", "complaint"]).match?(result)).to be true
    end

    it "does not match when event_type is not in the list" do
      expect(rule(field: "event_type", operator: "in", value: ["complaint"]).match?(result)).to be false
    end

    it "matches with 'not_in' operator" do
      expect(rule(field: "event_type", operator: "not_in", value: ["delivery"]).match?(result)).to be true
    end

    it "matches with 'eq' operator" do
      expect(rule(field: "event_type", operator: "eq", value: "bounce").match?(result)).to be true
    end

    it "does not match 'eq' with wrong value" do
      expect(rule(field: "event_type", operator: "eq", value: "delivery").match?(result)).to be false
    end

    it "matches with 'not_eq' operator" do
      expect(rule(field: "event_type", operator: "not_eq", value: "delivery").match?(result)).to be true
    end
  end

  describe "source field" do
    it "matches with 'eq'" do
      expect(rule(field: "source", operator: "eq", value: "noreply@myapp.com").match?(result)).to be true
    end

    it "matches with 'starts_with'" do
      expect(rule(field: "source", operator: "starts_with", value: "noreply@").match?(result)).to be true
    end

    it "matches with 'ends_with'" do
      expect(rule(field: "source", operator: "ends_with", value: "@myapp.com").match?(result)).to be true
    end

    it "matches with 'contains'" do
      expect(rule(field: "source", operator: "contains", value: "myapp").match?(result)).to be true
    end

    it "does not match when source does not start with value" do
      expect(rule(field: "source", operator: "starts_with", value: "admin@").match?(result)).to be false
    end
  end

  describe "destination field (array)" do
    it "matches 'contains' if ANY recipient matches" do
      expect(rule(field: "destination", operator: "contains", value: "alice").match?(result)).to be true
    end

    it "matches 'ends_with' against any recipient domain" do
      expect(rule(field: "destination", operator: "ends_with", value: "@test.org").match?(result)).to be true
    end

    it "matches 'starts_with' against any recipient" do
      expect(rule(field: "destination", operator: "starts_with", value: "bob@").match?(result)).to be true
    end

    it "does not match if no recipient satisfies the rule" do
      expect(rule(field: "destination", operator: "starts_with", value: "charlie@").match?(result)).to be false
    end

    it "matches 'eq' against any recipient" do
      expect(rule(field: "destination", operator: "eq", value: "alice@example.com").match?(result)).to be true
    end
  end

  describe "subject field" do
    it "matches with 'contains'" do
      expect(rule(field: "subject", operator: "contains", value: "invoice").match?(result)).to be true
    end

    it "matches with 'starts_with'" do
      expect(rule(field: "subject", operator: "starts_with", value: "Your").match?(result)).to be true
    end

    it "does not match wrong substring" do
      expect(rule(field: "subject", operator: "contains", value: "receipt").match?(result)).to be false
    end
  end

  describe "unknown operator" do
    it "returns false" do
      expect(rule(field: "event_type", operator: "regex", value: ".*").match?(result)).to be false
    end
  end

  describe "symbol keys" do
    it "works with symbol keys in the rule hash" do
      r = described_class.new(field: "event_type", operator: "in", value: ["bounce"])
      expect(r.match?(result)).to be true
    end
  end
end
