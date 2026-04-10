require "rails_helper"

RSpec.describe "Emails activity log", type: :system do
  before do
    SesDashboard.configure { |c| c.authentication_adapter = :none }
  end

  let(:project) { create(:ses_dashboard_project, name: "Test Project") }

  describe "index" do
    it "shows the Activity heading and filter form" do
      visit project_emails_path(project)

      expect(page).to have_css("h1", text: "Activity — Test Project")
      expect(page).to have_field("Search")
      expect(page).to have_select("status")
    end

    it "shows an empty-state message when there are no emails" do
      visit project_emails_path(project)

      expect(page).to have_text("No emails found")
    end

    it "lists emails with their subject, status, and a Details link" do
      create(:ses_dashboard_email, project: project, subject: "Welcome!", status: "delivered",
             source: "app@example.com", sent_at: 1.hour.ago)
      create(:ses_dashboard_email, project: project, subject: "Invoice #42", status: "bounced",
             source: "billing@example.com", sent_at: 30.minutes.ago)

      visit project_emails_path(project)

      within("tbody") do
        expect(page).to have_text("Welcome!")
        expect(page).to have_text("Invoice #42")
        expect(page).to have_text("Delivered")
        expect(page).to have_text("Bounced")
        expect(page).to have_link("Details", count: 2)
      end
    end

    it "links to CSV and JSON exports" do
      visit project_emails_path(project)

      expect(page).to have_link("Export CSV")
      expect(page).to have_link("Export JSON")
    end
  end

  describe "filtering" do
    before do
      create(:ses_dashboard_email, project: project, subject: "Delivered Email",
             status: "delivered", sent_at: 1.hour.ago)
      create(:ses_dashboard_email, project: project, subject: "Bounced Email",
             status: "bounced", sent_at: 2.hours.ago)
    end

    it "filters by status" do
      visit project_emails_path(project)

      select "Delivered", from: "status"
      click_button "Filter"

      expect(page).to have_text("Delivered Email")
      expect(page).not_to have_text("Bounced Email")
    end

    it "filters by search query" do
      visit project_emails_path(project)

      fill_in "Search", with: "Delivered"
      click_button "Filter"

      expect(page).to have_text("Delivered Email")
      expect(page).not_to have_text("Bounced Email")
    end

    it "resets filters when Reset is clicked" do
      visit project_emails_path(project, status: "delivered")

      expect(page).to have_text("Delivered Email")
      expect(page).not_to have_text("Bounced Email")

      click_link "Reset"

      expect(page).to have_text("Delivered Email")
      expect(page).to have_text("Bounced Email")
    end
  end

  describe "email detail" do
    it "shows the email subject on the detail page" do
      email = create(:ses_dashboard_email, project: project, subject: "Hello World",
                     status: "delivered", sent_at: 1.hour.ago)

      visit project_emails_path(project)
      click_link "Details", match: :first

      expect(page).to have_text("Hello World")
    end
  end
end
