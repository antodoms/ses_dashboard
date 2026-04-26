require "spec_helper"

RSpec.describe SesDashboard::WebhookProcessor do
  def sns_envelope(type, message_body)
    {
      "Type"      => type,
      "Timestamp" => "2024-01-15T10:00:00Z",
      "Message"   => message_body.to_json
    }.to_json
  end

  def delivery_event
    {
      "eventType" => "Delivery",
      "mail" => {
        "messageId"  => "msg-abc123",
        "source"     => "sender@example.com",
        "destination" => ["recipient@example.com"],
        "timestamp"  => "2024-01-15T10:00:00Z",
        "commonHeaders" => { "subject" => "Hello" }
      },
      "delivery" => { "timestamp" => "2024-01-15T10:00:05Z" }
    }
  end

  def bounce_event
    {
      "notificationType" => "Bounce",
      "mail" => {
        "messageId"  => "msg-bounce1",
        "source"     => "sender@example.com",
        "destination" => ["bad@example.com"],
        "timestamp"  => "2024-01-15T11:00:00Z"
      },
      "bounce" => { "bounceType" => "Permanent" }
    }
  end

  describe "#process" do
    context "SNS subscription confirmation" do
      it "returns a :confirm_subscription result with the SubscribeURL" do
        body = { "Type" => "SubscriptionConfirmation", "SubscribeURL" => "https://sns.aws.com/confirm" }.to_json
        result = described_class.new(body).process

        expect(result.action).to eq(:confirm_subscription)
        expect(result.subscribe_url).to eq("https://sns.aws.com/confirm")
      end
    end

    context "SNS Notification — new event publishing format (eventType)" do
      it "processes a delivery event" do
        body   = sns_envelope("Notification", delivery_event)
        result = described_class.new(body).process

        expect(result.action).to     eq(:process_event)
        expect(result.event_type).to eq("delivery")
        expect(result.message_id).to eq("msg-abc123")
        expect(result.source).to     eq("sender@example.com")
        expect(result.destination).to include("recipient@example.com")
        expect(result.subject).to    eq("Hello")
        expect(result.occurred_at).to be_a(Time)
      end
    end

    context "SNS Notification — legacy feedback format (notificationType)" do
      it "processes a bounce event" do
        body   = sns_envelope("Notification", bounce_event)
        result = described_class.new(body).process

        expect(result.action).to     eq(:process_event)
        expect(result.event_type).to eq("bounce")
        expect(result.message_id).to eq("msg-bounce1")
      end
    end

    context "open, click, complaint, send, reject events" do
      %w[send delivery bounce complaint open click reject].each do |evt|
        it "normalizes '#{evt}' event type" do
          inner = {
            "eventType" => evt.capitalize,
            "mail"      => { "messageId" => "id-1", "source" => "a@b.com",
                             "destination" => ["c@d.com"], "timestamp" => "2024-01-01T00:00:00Z" }
          }
          body   = sns_envelope("Notification", inner)
          result = described_class.new(body).process

          expect(result.event_type).to eq(evt)
        end
      end
    end

    context "SNS raw message delivery (no envelope)" do
      # When a subscription has raw message delivery enabled, SNS posts the SES
      # event JSON directly — no {"Type":"Notification","Message":"..."} wrapper.

      it "processes a raw delivery event" do
        body   = delivery_event.to_json
        result = described_class.new(body).process

        expect(result.action).to     eq(:process_event)
        expect(result.event_type).to eq("delivery")
        expect(result.message_id).to eq("msg-abc123")
        expect(result.source).to     eq("sender@example.com")
        expect(result.destination).to include("recipient@example.com")
        expect(result.subject).to    eq("Hello")
        expect(result.occurred_at).to be_a(Time)
      end

      it "processes a raw send event" do
        raw = {
          "eventType" => "Send",
          "mail" => {
            "messageId"   => "msg-raw-send",
            "source"      => "sender@example.com",
            "destination" => ["to@example.com"],
            "timestamp"   => "2024-01-15T10:00:00Z"
          }
        }
        result = described_class.new(raw.to_json).process

        expect(result.action).to     eq(:process_event)
        expect(result.event_type).to eq("send")
        expect(result.message_id).to eq("msg-raw-send")
      end

      it "processes a raw bounce event" do
        raw = {
          "eventType" => "Bounce",
          "mail" => {
            "messageId"   => "msg-raw-bounce",
            "source"      => "sender@example.com",
            "destination" => ["bad@example.com"],
            "timestamp"   => "2024-01-15T10:00:00Z"
          }
        }
        result = described_class.new(raw.to_json).process

        expect(result.action).to     eq(:process_event)
        expect(result.event_type).to eq("bounce")
      end

      it "processes a raw open event" do
        raw = {
          "eventType" => "Open",
          "mail" => {
            "messageId"   => "msg-raw-open",
            "source"      => "sender@example.com",
            "destination" => ["to@example.com"],
            "timestamp"   => "2024-01-15T10:00:00Z"
          }
        }
        result = described_class.new(raw.to_json).process

        expect(result.action).to     eq(:process_event)
        expect(result.event_type).to eq("open")
      end

      it "falls back to mail timestamp when sns_timestamp is absent" do
        raw = {
          "eventType" => "Send",
          "mail" => {
            "messageId"   => "msg-ts",
            "source"      => "a@b.com",
            "destination" => ["c@d.com"],
            "timestamp"   => "2024-06-01T12:00:00Z"
          }
        }
        result = described_class.new(raw.to_json).process

        expect(result.occurred_at).to eq(Time.parse("2024-06-01T12:00:00Z").utc)
      end

      %w[send delivery bounce complaint open click reject].each do |evt|
        it "normalizes raw '#{evt}' event type without envelope" do
          raw = {
            "eventType" => evt.capitalize,
            "mail" => {
              "messageId"   => "id-raw-#{evt}",
              "source"      => "a@b.com",
              "destination" => ["c@d.com"],
              "timestamp"   => "2024-01-01T00:00:00Z"
            }
          }
          result = described_class.new(raw.to_json).process
          expect(result.event_type).to eq(evt)
        end
      end
    end

    context "malformed input" do
      it "returns :unknown for invalid JSON" do
        result = described_class.new("not-json").process
        expect(result.action).to eq(:unknown)
      end

      it "returns :unknown for an empty body" do
        result = described_class.new("").process
        expect(result.action).to eq(:unknown)
      end
    end
  end
end
