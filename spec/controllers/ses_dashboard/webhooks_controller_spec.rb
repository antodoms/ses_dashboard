require "rails_helper"

RSpec.describe SesDashboard::WebhooksController, type: :controller do
  routes { SesDashboard::Engine.routes }

  let(:project) { create(:ses_dashboard_project) }

  def sns_notification(event_type, message_id: "msg-#{SecureRandom.hex(4)}", signed: false)
    inner = {
      "eventType" => event_type.capitalize,
      "mail" => {
        "messageId"   => message_id,
        "source"      => "sender@example.com",
        "destination" => ["to@example.com"],
        "timestamp"   => "2024-01-15T10:00:00Z",
        "commonHeaders" => { "subject" => "Test" }
      }
    }
    envelope = {
      "Type"           => "Notification",
      "MessageId"      => SecureRandom.hex(8),
      "TopicArn"       => "arn:aws:sns:us-east-1:123456789:test",
      "Timestamp"      => "2024-01-15T10:00:00.000Z",
      "Message"        => inner.to_json,
      "Signature"      => "fake",
      "SignatureVersion" => "2"
    }
    envelope["SigningCertURL"] = "https://sns.us-east-1.amazonaws.com/cert.pem" if signed
    envelope.to_json
  end

  def json_post(project_token, body)
    request.env["CONTENT_TYPE"]   = "application/json"
    request.env["CONTENT_LENGTH"] = body.bytesize.to_s
    post :create, params: { project_token: project_token }, body: body
  end

  describe "POST #create" do
    context "with a valid project token" do
      it "returns 200 OK" do
        json_post(project.token, sns_notification("delivery"))
        expect(response).to have_http_status(:ok)
      end

      it "creates an Email record on first notification" do
        body = sns_notification("send", message_id: "unique-msg-1")
        expect {
          json_post(project.token, body)
        }.to change(SesDashboard::Email, :count).by(1)
      end

      it "creates an EmailEvent record" do
        body = sns_notification("delivery", message_id: "unique-msg-2")
        expect {
          json_post(project.token, body)
        }.to change(SesDashboard::EmailEvent, :count).by(1)
      end

      it "idempotently reuses the same Email record for subsequent events" do
        json_post(project.token, sns_notification("send", message_id: "same-msg"))

        body = sns_notification("delivery", message_id: "same-msg")
        expect {
          json_post(project.token, body)
        }.not_to change(SesDashboard::Email, :count)
      end
    end

    context "raw message delivery (no SNS envelope)" do
      def raw_notification(event_type, message_id: "raw-#{SecureRandom.hex(4)}")
        {
          "eventType" => event_type.capitalize,
          "mail" => {
            "messageId"   => message_id,
            "source"      => "sender@example.com",
            "destination" => ["to@example.com"],
            "timestamp"   => "2024-01-15T10:00:00Z"
          }
        }.to_json
      end

      it "persists the email" do
        expect {
          json_post(project.token, raw_notification("send"))
        }.to change(SesDashboard::Email, :count).by(1)
      end

      it "persists the event" do
        expect {
          json_post(project.token, raw_notification("delivery"))
        }.to change(SesDashboard::EmailEvent, :count).by(1)
      end

      it "returns 200 OK" do
        json_post(project.token, raw_notification("send"))
        expect(response).to have_http_status(:ok)
      end
    end

    context "SNS SubscriptionConfirmation" do
      it "hits the SubscribeURL and returns 200" do
        body = {
          "Type"         => "SubscriptionConfirmation",
          "SubscribeURL" => "https://sns.us-east-1.amazonaws.com/confirm?token=abc"
        }.to_json

        expect(Net::HTTP).to receive(:get).with(URI("https://sns.us-east-1.amazonaws.com/confirm?token=abc"))
        json_post(project.token, body)
        expect(response).to have_http_status(:ok)
      end
    end

    context "with an invalid token" do
      it "returns 404" do
        json_post("invalid-token", sns_notification("delivery"))
        expect(response).to have_http_status(:not_found)
      end
    end

    context "SNS signature verification" do
      before do
        SesDashboard.configure { |c| c.verify_sns_signature = true }
      end

      it "returns 200 and persists the event when verification passes" do
        allow_any_instance_of(SesDashboard::SnsSignatureVerifier).to receive(:verify!).and_return(true)
        expect {
          json_post(project.token, sns_notification("delivery", signed: true))
        }.to change(SesDashboard::Email, :count).by(1)
        expect(response).to have_http_status(:ok)
      end

      it "returns 403 when signature verification fails" do
        allow_any_instance_of(SesDashboard::SnsSignatureVerifier)
          .to receive(:verify!)
          .and_raise(SesDashboard::SnsSignatureVerifier::VerificationError, "bad signature")

        json_post(project.token, sns_notification("delivery", signed: true))
        expect(response).to have_http_status(:forbidden)
      end

      it "does not persist the event when verification fails" do
        allow_any_instance_of(SesDashboard::SnsSignatureVerifier)
          .to receive(:verify!)
          .and_raise(SesDashboard::SnsSignatureVerifier::VerificationError, "bad signature")

        expect {
          json_post(project.token, sns_notification("delivery", signed: true))
        }.not_to change(SesDashboard::Email, :count)
      end

      it "skips verification for raw delivery (no SigningCertURL in body)" do
        raw_body = {
          "eventType" => "Delivery",
          "mail" => {
            "messageId"   => "raw-msg-skip-verify",
            "source"      => "sender@example.com",
            "destination" => ["to@example.com"],
            "timestamp"   => "2024-01-15T10:00:00Z"
          }
        }.to_json

        expect(SesDashboard::SnsSignatureVerifier).not_to receive(:new)
        json_post(project.token, raw_body)
        expect(response).to have_http_status(:ok)
      end

      it "does not verify when verify_sns_signature is false" do
        SesDashboard.configure { |c| c.verify_sns_signature = false }
        expect(SesDashboard::SnsSignatureVerifier).not_to receive(:new)
        json_post(project.token, sns_notification("delivery"))
        expect(response).to have_http_status(:ok)
      end
    end

    context "webhook forwarding with project-level rules" do
      def stub_forward_post(url)
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

      it "forwards to the configured URL when rules match" do
        forward_url = "https://hooks.zapier.com/bounce-alert"
        project.webhook_forwards = [
          { "url" => forward_url,
            "rules" => [{ "field" => "event_type", "operator" => "in", "value" => ["bounce"] }] }
        ]
        project.save!

        http = stub_forward_post(forward_url)
        expect(http).to receive(:request) do |req|
          body = JSON.parse(req.body)
          expect(body["event_type"]).to eq("bounce")
          expect(body["source"]).to eq("sender@example.com")
          instance_double(Net::HTTPSuccess, is_a?: true, code: "200")
        end

        json_post(project.token, sns_notification("bounce"))
        expect(response).to have_http_status(:ok)
      end

      it "does not forward when rules do not match" do
        project.webhook_forwards = [
          { "url" => "https://hooks.zapier.com/bounce-only",
            "rules" => [{ "field" => "event_type", "operator" => "in", "value" => ["bounce"] }] }
        ]
        project.save!

        expect(Net::HTTP).not_to receive(:new).with("hooks.zapier.com", 443)

        json_post(project.token, sns_notification("delivery"))
        expect(response).to have_http_status(:ok)
      end

      it "forwards when source rule matches" do
        forward_url = "https://example.com/source-filter"
        project.webhook_forwards = [
          { "url" => forward_url,
            "rules" => [{ "field" => "source", "operator" => "ends_with", "value" => "@example.com" }] }
        ]
        project.save!

        http = stub_forward_post(forward_url)
        expect(http).to receive(:request).and_return(
          instance_double(Net::HTTPSuccess, is_a?: true, code: "200")
        )

        json_post(project.token, sns_notification("delivery"))
        expect(response).to have_http_status(:ok)
      end

      it "evaluates multiple rules with AND logic" do
        project.webhook_forwards = [
          { "url" => "https://example.com/strict",
            "rules" => [
              { "field" => "event_type", "operator" => "in", "value" => ["bounce"] },
              { "field" => "source", "operator" => "starts_with", "value" => "admin@" }
            ] }
        ]
        project.save!

        # event_type matches (bounce) but source does not (sender@example.com, not admin@)
        expect(Net::HTTP).not_to receive(:new).with("example.com", 443)

        json_post(project.token, sns_notification("bounce"))
        expect(response).to have_http_status(:ok)
      end

      it "forwards all events when no rules are configured" do
        forward_url = "https://example.com/all"
        project.webhook_forwards = [{ "url" => forward_url }]
        project.save!

        http = stub_forward_post(forward_url)
        expect(http).to receive(:request).and_return(
          instance_double(Net::HTTPSuccess, is_a?: true, code: "200")
        )

        json_post(project.token, sns_notification("delivery"))
        expect(response).to have_http_status(:ok)
      end

      it "falls back to global config when project has no forwards" do
        forward_url = "https://global.example.com/hook"
        SesDashboard.configure do |c|
          c.webhook_forwards = [
            { url: forward_url,
              rules: [{ field: "event_type", operator: "in", value: ["bounce"] }] }
          ]
        end

        http = stub_forward_post(forward_url)
        expect(http).to receive(:request).and_return(
          instance_double(Net::HTTPSuccess, is_a?: true, code: "200")
        )

        json_post(project.token, sns_notification("bounce"))
        expect(response).to have_http_status(:ok)
      end

      it "does not forward from global config when project has its own forwards" do
        project.webhook_forwards = [
          { "url" => "https://project.example.com/hook",
            "rules" => [{ "field" => "event_type", "operator" => "in", "value" => ["complaint"] }] }
        ]
        project.save!

        SesDashboard.configure do |c|
          c.webhook_forwards = [{ url: "https://global.example.com/should-not-fire" }]
        end

        # Project rules require complaint, but event is bounce → no forward at all
        expect(Net::HTTP).not_to receive(:new)

        json_post(project.token, sns_notification("bounce"))
        expect(response).to have_http_status(:ok)
      end

      it "still persists the event even when forwarding fails" do
        project.webhook_forwards = [{ "url" => "https://down.example.com/fail" }]
        project.save!

        uri  = URI("https://down.example.com/fail")
        http = instance_double(Net::HTTP)
        allow(Net::HTTP).to receive(:new).with(uri.host, uri.port).and_return(http)
        allow(http).to receive(:use_ssl=)
        allow(http).to receive(:open_timeout=)
        allow(http).to receive(:read_timeout=)
        allow(http).to receive(:request).and_raise(Net::OpenTimeout, "timed out")

        expect {
          json_post(project.token, sns_notification("bounce"))
        }.to change(SesDashboard::Email, :count).by(1)

        expect(response).to have_http_status(:ok)
      end
    end
  end
end
