require "rails_helper"

RSpec.describe SesDashboard::WebhooksController, type: :controller do
  routes { SesDashboard::Engine.routes }

  let(:project) { create(:ses_dashboard_project) }

  def sns_notification(event_type, message_id: "msg-#{SecureRandom.hex(4)}")
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
    { "Type" => "Notification", "Message" => inner.to_json }.to_json
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

    context "with an invalid token" do
      it "returns 404" do
        json_post("invalid-token", sns_notification("delivery"))
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
