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

  describe "POST #create" do
    context "with a valid project token" do
      it "returns 200 OK" do
        request.env["CONTENT_TYPE"] = "application/json"
        request.env["RAW_POST_DATA"] = sns_notification("delivery")
        post :create, params: { project_token: project.token }
        expect(response).to have_http_status(:ok)
      end

      it "creates an Email record on first notification" do
        request.env["CONTENT_TYPE"] = "application/json"
        request.env["RAW_POST_DATA"] = sns_notification("send", message_id: "unique-msg-1")
        expect {
          post :create, params: { project_token: project.token }
        }.to change(SesDashboard::Email, :count).by(1)
      end

      it "creates an EmailEvent record" do
        request.env["CONTENT_TYPE"] = "application/json"
        request.env["RAW_POST_DATA"] = sns_notification("delivery", message_id: "unique-msg-2")
        expect {
          post :create, params: { project_token: project.token }
        }.to change(SesDashboard::EmailEvent, :count).by(1)
      end

      it "idempotently reuses the same Email record for subsequent events" do
        request.env["CONTENT_TYPE"] = "application/json"
        request.env["RAW_POST_DATA"] = sns_notification("send",     message_id: "same-msg")
        post :create, params: { project_token: project.token }
        request.env["RAW_POST_DATA"] = sns_notification("delivery", message_id: "same-msg")

        expect {
          post :create, params: { project_token: project.token }
        }.not_to change(SesDashboard::Email, :count)
      end
    end

    context "with an invalid token" do
      it "returns 404" do
        request.env["RAW_POST_DATA"] = sns_notification("delivery")
        post :create, params: { project_token: "invalid-token" }
        expect(response).to have_http_status(:not_found)
      end
    end
  end
end
