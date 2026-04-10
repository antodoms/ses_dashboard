FactoryBot.define do
  factory :ses_dashboard_project, class: "SesDashboard::Project" do
    name        { "My App #{SecureRandom.hex(4)}" }
    description { "A test project" }
  end
end
