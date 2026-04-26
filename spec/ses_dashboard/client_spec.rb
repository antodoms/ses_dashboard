require "spec_helper"

RSpec.describe SesDashboard::Client do
  subject(:client) { described_class.new(region: "us-east-1", stub_responses: true) }

  describe "SES data retrieval" do
    it "fetches send quota from SES" do
      client.send(:ses_client).stub_responses(:get_send_quota, {
        max_24_hour_send: 200.0,
        max_send_rate: 1.0,
        sent_last_24_hours: 10.0
      })

      response = client.send_quota

      expect(response.max_24_hour_send).to eq(200.0)
      expect(response.max_send_rate).to eq(1.0)
      expect(response.sent_last_24_hours).to eq(10.0)
    end

    it "caches send quota results when caching is enabled" do
      client.send(:ses_client).stub_responses(:get_send_quota, [{ max_24_hour_send: 200.0 }, { max_24_hour_send: 300.0 }])

      first = client.send_quota
      second = client.send_quota

      expect(first.max_24_hour_send).to eq(200.0)
      expect(second.max_24_hour_send).to eq(200.0)
    end

    it "fetches send statistics from SES" do
      client.send(:ses_client).stub_responses(:get_send_statistics, {
        send_data_points: [{ timestamp: Time.now, delivery_attempts: 5, bounces: 0, complaints: 0, rejects: 0 }]
      })

      response = client.send_statistics

      expect(response.send_data_points).not_to be_empty
      expect(response.send_data_points.first.delivery_attempts).to eq(5)
    end

    it "fetches identity verification attributes" do
      client.send(:ses_client).stub_responses(:get_identity_verification_attributes, {
        verification_attributes: {
          "user@example.com" => {
            verification_status: "Success"
          }
        }
      })

      response = client.get_identity_verification_attributes(["user@example.com"])

      expect(response.verification_attributes).to include("user@example.com")
    end
  end

  describe "#send_email" do
    it "sends an email using the correct SES API parameters" do
      ses = client.send(:ses_client)
      ses.stub_responses(:send_email, message_id: "test-message-id")

      response = client.send_email(
        from: "sender@example.com",
        to: "recipient@example.com",
        subject: "Hello",
        body: "Test body"
      )

      expect(response.message_id).to eq("test-message-id")
    end

    it "uses destination.to_addresses not destinations" do
      ses = client.send(:ses_client)
      ses.stub_responses(:send_email, message_id: "msg-1")

      expect(ses).to receive(:send_email).with(
        hash_including(
          destination: { to_addresses: ["b@example.com"] }
        )
      ).and_call_original

      client.send_email(from: "a@example.com", to: "b@example.com", subject: "Hi", body: "Body")
    end
  end
end
