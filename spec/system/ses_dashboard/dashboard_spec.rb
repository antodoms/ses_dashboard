require "rails_helper"

RSpec.describe "Dashboard", type: :system do
  before do
    SesDashboard.configure { |c| c.authentication_adapter = :none }
  end

  it "shows the Dashboard heading and stat cards" do
    visit root_path

    expect(page).to have_css("h1", text: "Dashboard")
    expect(page).to have_css(".card-title", text: /sent/i)
    expect(page).to have_css(".card-title", text: /delivered/i)
    expect(page).to have_css(".card-title", text: /opens/i)
    expect(page).to have_css(".card-title", text: /clicks/i)
    expect(page).to have_css(".card-title", text: /not delivered/i)
  end

  it "renders the chart canvas" do
    visit root_path

    expect(page).to have_css("canvas#activity-chart")
  end

  it "shows stat totals that reflect the database" do
    project = create(:ses_dashboard_project)
    create(:ses_dashboard_email, project: project, status: "delivered",
           sent_at: Time.current, opens: 2, clicks: 1)
    create(:ses_dashboard_email, project: project, status: "bounced",
           sent_at: Time.current)

    visit root_path

    within(".stat-grid") do
      # "Sent" card shows total count (2 emails)
      expect(page).to have_css(".card-value", text: "2")
      # "Delivered" card shows 1
      expect(page).to have_css(".card-value", text: "1")
    end
  end

  it "lists projects with links to their activity log" do
    create(:ses_dashboard_project, name: "Acme Emails")

    visit root_path

    expect(page).to have_link("Acme Emails")
    expect(page).to have_link("View activity")
  end

  it "shows an empty-state message when there are no projects" do
    visit root_path

    expect(page).to have_text("No projects yet")
    expect(page).to have_link("Create one")
  end

  it "links to the projects management page" do
    visit root_path

    click_link "Manage projects"

    expect(page).to have_css("h1", text: "Projects")
  end
end
