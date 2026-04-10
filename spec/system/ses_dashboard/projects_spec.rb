require "rails_helper"

RSpec.describe "Projects", type: :system do
  before do
    SesDashboard.configure { |c| c.authentication_adapter = :none }
  end

  describe "index" do
    it "shows the Projects heading and a link to create a new project" do
      visit projects_path

      expect(page).to have_css("h1", text: "Projects")
      expect(page).to have_link("New project")
    end

    it "shows an empty-state message when there are no projects" do
      visit projects_path

      expect(page).to have_text("No projects yet")
    end

    it "lists existing projects" do
      create(:ses_dashboard_project, name: "Alpha App")
      create(:ses_dashboard_project, name: "Beta App")

      visit projects_path

      expect(page).to have_link("Alpha App")
      expect(page).to have_link("Beta App")
    end
  end

  describe "create" do
    it "creates a project and lands on the project show page" do
      visit new_project_path

      fill_in "Name",        with: "My New Project"
      fill_in "Description", with: "Tracks transactional email"
      click_button "Create Project"

      expect(page).to have_css("h1", text: "My New Project")
      expect(page).to have_text("Tracks transactional email")
    end

    it "shows validation errors when name is blank" do
      visit new_project_path

      fill_in "Name", with: ""
      click_button "Create Project"

      expect(page).to have_text("Name can't be blank")
    end
  end

  describe "show (project dashboard)" do
    it "displays stat cards and the chart canvas" do
      project = create(:ses_dashboard_project, name: "Gamma App")

      visit project_path(project)

      expect(page).to have_css("h1", text: "Gamma App")
      expect(page).to have_css(".card-title", text: /sent/i)
      expect(page).to have_css(".card-title", text: /delivered/i)
      expect(page).to have_css("canvas#activity-chart")
    end

    it "shows the SNS webhook URL" do
      project = create(:ses_dashboard_project)

      visit project_path(project)

      expect(page).to have_text(/sns webhook url/i)
      expect(page).to have_css(".webhook-url-input")
    end

    it "links to the activity log" do
      project = create(:ses_dashboard_project, name: "Delta")

      visit project_path(project)

      expect(page).to have_link("Activity log")
    end
  end

  describe "edit" do
    it "updates the project name" do
      project = create(:ses_dashboard_project, name: "Old Name")

      visit edit_project_path(project)

      fill_in "Name", with: "New Name"
      click_button "Update Project"

      expect(page).to have_css("h1", text: "New Name")
    end
  end
end
