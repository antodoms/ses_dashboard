require "spec_helper"
require "ses_dashboard"

RSpec.describe SesDashboard::WebhookForwarder do
  let(:result) do
    SesDashboard::WebhookProcessor::Result.new(
      action:      :process_event,
      event_type:  "bounce",
      message_id:  "msg-abc123",
      source:      "noreply@myapp.com",
      destination: ["alice@example.com"],
      subject:     "Hello",
      occurred_at: Time.utc(2024, 1, 15, 10, 0, 0),
      raw_payload: { "eventType" => "Bounce" }
    )
  end

  def project_with(forwards)
    double("Project", effective_webhook_forwards: forwards)
  end

  def stub_http_post(url)
    uri  = URI(url)
    http = instance_double(Net::HTTP)
    allow(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(http)
    allow(http).to receive(:use_ssl=)
    allow(http).to receive(:open_timeout=)
    allow(http).to receive(:read_timeout=)
    allow(http).to receive(:request).and_return(
      instance_double(Net::HTTPSuccess, is_a?: true, code: "200")
    )
    http
  end

  describe "#forward" do
    context "when no forwards are configured" do
      it "does nothing" do
        expect(Net::HTTP).not_to receive(:new)
        described_class.new(project_with([]), result).forward
      end
    end

    context "with rules-based matching" do
      let(:forward_url) { "https://hooks.zapier.com/hooks/catch/abc/xyz/" }

      it "forwards when all rules match" do
        project = project_with([{
          "url" => forward_url,
          "rules" => [
            { "field" => "event_type", "operator" => "in", "value" => ["bounce", "complaint"] },
            { "field" => "source", "operator" => "ends_with", "value" => "@myapp.com" }
          ]
        }])
        http = stub_http_post(forward_url)
        expect(http).to receive(:request)
        described_class.new(project, result).forward
      end

      it "does not forward when any rule fails" do
        project = project_with([{
          "url" => forward_url,
          "rules" => [
            { "field" => "event_type", "operator" => "in", "value" => ["bounce"] },
            { "field" => "source", "operator" => "starts_with", "value" => "admin@" }
          ]
        }])
        expect(Net::HTTP).not_to receive(:new)
        described_class.new(project, result).forward
      end

      it "forwards when no rules are specified (match all)" do
        http = stub_http_post(forward_url)
        expect(http).to receive(:request)
        described_class.new(project_with([{ "url" => forward_url, "rules" => [] }]), result).forward
      end

      it "filters by destination" do
        project = project_with([{
          "url" => forward_url,
          "rules" => [
            { "field" => "destination", "operator" => "ends_with", "value" => "@example.com" }
          ]
        }])
        http = stub_http_post(forward_url)
        expect(http).to receive(:request)
        described_class.new(project, result).forward
      end

      it "skips when destination does not match" do
        project = project_with([{
          "url" => forward_url,
          "rules" => [
            { "field" => "destination", "operator" => "starts_with", "value" => "ceo@" }
          ]
        }])
        expect(Net::HTTP).not_to receive(:new)
        described_class.new(project, result).forward
      end
    end

    context "with legacy event_types shorthand" do
      let(:forward_url) { "https://hooks.zapier.com/legacy" }

      it "forwards when event_type is in the list" do
        project = project_with([{ "url" => forward_url, "event_types" => ["bounce"] }])
        http = stub_http_post(forward_url)
        expect(http).to receive(:request)
        described_class.new(project, result).forward
      end

      it "does not forward when event_type is not in the list" do
        project = project_with([{ "url" => forward_url, "event_types" => ["complaint"] }])
        expect(Net::HTTP).not_to receive(:new)
        described_class.new(project, result).forward
      end

      it "forwards all when event_types is empty" do
        project = project_with([{ "url" => forward_url, "event_types" => [] }])
        http = stub_http_post(forward_url)
        expect(http).to receive(:request)
        described_class.new(project, result).forward
      end
    end

    context "payload" do
      let(:forward_url) { "https://hooks.zapier.com/payload-check" }

      it "POSTs a normalized JSON payload" do
        project = project_with([{ "url" => forward_url }])
        http = stub_http_post(forward_url)
        expect(http).to receive(:request) do |req|
          expect(req).to be_a(Net::HTTP::Post)
          expect(req["Content-Type"]).to eq("application/json")
          body = JSON.parse(req.body)
          expect(body["event_type"]).to  eq("bounce")
          expect(body["message_id"]).to  eq("msg-abc123")
          expect(body["source"]).to      eq("noreply@myapp.com")
          expect(body["destination"]).to eq(["alice@example.com"])
          expect(body["subject"]).to     eq("Hello")
          expect(body["occurred_at"]).to eq("2024-01-15T10:00:00Z")
          expect(body["raw"]).to         eq({ "eventType" => "Bounce" })
          instance_double(Net::HTTPSuccess, is_a?: true, code: "200")
        end
        described_class.new(project, result).forward
      end
    end

    context "when multiple forwards are configured" do
      let(:bounce_url) { "https://hooks.zapier.com/bounce" }
      let(:all_url)    { "https://example.com/all" }

      it "POSTs to all matching URLs" do
        project = project_with([
          { "url" => bounce_url, "rules" => [{ "field" => "event_type", "operator" => "in", "value" => ["bounce"] }] },
          { "url" => all_url }
        ])
        http1 = stub_http_post(bounce_url)
        http2 = stub_http_post(all_url)
        expect(http1).to receive(:request).and_return(
          instance_double(Net::HTTPSuccess, is_a?: true, code: "200")
        )
        expect(http2).to receive(:request).and_return(
          instance_double(Net::HTTPSuccess, is_a?: true, code: "200")
        )
        described_class.new(project, result).forward
      end
    end

    context "when the HTTP request fails" do
      it "does not raise and continues processing" do
        forward_url = "https://example.com/hook"
        uri  = URI(forward_url)
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:request).and_raise(Net::OpenTimeout, "connection timed out")

        project = project_with([{ "url" => forward_url }])
        expect { described_class.new(project, result).forward }.not_to raise_error
      end
    end

    context "when the forward URL is missing" do
      it "skips that entry silently" do
        expect(Net::HTTP).not_to receive(:new)
        described_class.new(project_with([{ "rules" => [] }]), result).forward
      end
    end
  end
end
