FactoryBot.define do
  factory :ses_dashboard_email, class: "SesDashboard::Email" do
    association :project, factory: :ses_dashboard_project

    message_id  { "msg-#{SecureRandom.hex(8)}@email.amazonses.com" }
    destination { ["recipient@example.com"] }
    source      { "sender@example.com" }
    subject     { "Hello from SES" }
    status      { "sent" }
    opens       { 0 }
    clicks      { 0 }
    sent_at     { Time.current }
  end
end
