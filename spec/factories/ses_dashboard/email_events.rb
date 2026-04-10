FactoryBot.define do
  factory :ses_dashboard_email_event, class: "SesDashboard::EmailEvent" do
    association :email, factory: :ses_dashboard_email

    event_type  { "delivery" }
    event_data  { { "eventType" => "Delivery" } }
    occurred_at { Time.current }
  end
end
