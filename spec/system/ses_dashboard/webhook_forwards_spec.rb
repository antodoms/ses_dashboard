require "rails_helper"

RSpec.describe "Webhook Forwards", type: :system do
  before do
    SesDashboard.configure { |c| c.authentication_adapter = :none }
  end

  describe "creating a project with webhook forwards" do
    it "persists forward targets with event_type rules to the database" do
      visit new_project_path

      fill_in "Name", with: "Zapier Bounce Alerts"

      click_button "+ Add Forward Target"

      within all(".wf-target").last do
        find("input.wf-url").set("https://hooks.zapier.com/hooks/catch/123/abc/")
        click_button "+ Add Rule"
        find("input.wf-event-cb[value='bounce']").check
        find("input.wf-event-cb[value='complaint']").check
      end

      click_button "Create Project"

      expect(page).to have_css("h1", text: "Zapier Bounce Alerts")

      project = SesDashboard::Project.last
      forwards = project.webhook_forwards
      expect(forwards.length).to eq(1)
      expect(forwards[0]["url"]).to eq("https://hooks.zapier.com/hooks/catch/123/abc/")
      expect(forwards[0]["rules"].length).to eq(1)

      rule = forwards[0]["rules"][0]
      expect(rule["field"]).to eq("event_type")
      expect(rule["operator"]).to eq("in")
      expect(rule["value"]).to match_array(["bounce", "complaint"])
    end

    it "creates a project with no rules (forward all events)" do
      visit new_project_path

      fill_in "Name", with: "All Events"
      click_button "+ Add Forward Target"

      within all(".wf-target").last do
        find("input.wf-url").set("https://example.com/all")
      end

      click_button "Create Project"

      expect(page).to have_css("h1", text: "All Events")

      project = SesDashboard::Project.last
      forwards = project.webhook_forwards
      expect(forwards.length).to eq(1)
      expect(forwards[0]["url"]).to eq("https://example.com/all")
      expect(forwards[0]).not_to have_key("rules")
    end
  end

  describe "editing existing webhook forwards" do
    it "loads stored rules into the UI and allows modification" do
      project = create(:ses_dashboard_project, name: "Edit Test")
      project.webhook_forwards = [
        { "url" => "https://example.com/hook",
          "rules" => [{ "field" => "event_type", "operator" => "in", "value" => ["bounce"] }] }
      ]
      project.save!

      visit edit_project_path(project)

      # Verify existing data loaded
      expect(find("input.wf-url").value).to eq("https://example.com/hook")

      within all(".wf-rule").first do
        expect(find("input.wf-event-cb[value='bounce']")).to be_checked
        expect(find("input.wf-event-cb[value='complaint']")).not_to be_checked

        # Add complaint to the existing rule
        find("input.wf-event-cb[value='complaint']").check
      end

      click_button "Update Project"

      expect(page).to have_css("h1", text: "Edit Test")

      project.reload
      expect(project.webhook_forwards[0]["rules"][0]["value"]).to match_array(["bounce", "complaint"])
    end

    it "preserves rules when updating other project fields" do
      project = create(:ses_dashboard_project, name: "Preserve Rules")
      project.webhook_forwards = [
        { "url" => "https://hooks.zapier.com/keep",
          "rules" => [{ "field" => "event_type", "operator" => "in", "value" => ["bounce"] }] }
      ]
      project.save!

      visit edit_project_path(project)

      fill_in "Name", with: "Renamed Project"
      click_button "Update Project"

      expect(page).to have_css("h1", text: "Renamed Project")

      project.reload
      expect(project.webhook_forwards.length).to eq(1)
      expect(project.webhook_forwards[0]["url"]).to eq("https://hooks.zapier.com/keep")
      expect(project.webhook_forwards[0]["rules"][0]["value"]).to eq(["bounce"])
    end
  end

  describe "multiple targets and rule types" do
    it "persists multiple targets with different rule types" do
      visit new_project_path

      fill_in "Name", with: "Multi Target"

      # Target 1: event_type filter
      click_button "+ Add Forward Target"
      within all(".wf-target")[0] do
        find("input.wf-url").set("https://hooks.zapier.com/bounces")
        click_button "+ Add Rule"
        find("input.wf-event-cb[value='bounce']").check
      end

      # Target 2: source-based filter
      click_button "+ Add Forward Target"
      within all(".wf-target")[1] do
        find("input.wf-url").set("https://example.com/alerts")
        click_button "+ Add Rule"

        # Change field to source, operator to contains
        find("select.wf-field").find(:option, "From (source)").select_option
        find("select.wf-operator").find(:option, "contains").select_option
        find("input.wf-value").set("noreply@myapp.com")
      end

      click_button "Create Project"

      expect(page).to have_css("h1", text: "Multi Target")

      project = SesDashboard::Project.last
      forwards = project.webhook_forwards
      expect(forwards.length).to eq(2)

      # Target 1
      expect(forwards[0]["url"]).to eq("https://hooks.zapier.com/bounces")
      expect(forwards[0]["rules"][0]).to eq(
        "field" => "event_type", "operator" => "in", "value" => ["bounce"]
      )

      # Target 2
      expect(forwards[1]["url"]).to eq("https://example.com/alerts")
      expect(forwards[1]["rules"][0]).to eq(
        "field" => "source", "operator" => "contains", "value" => "noreply@myapp.com"
      )
    end

    it "persists a target with multiple rules (AND logic)" do
      visit new_project_path

      fill_in "Name", with: "Multi Rule"

      click_button "+ Add Forward Target"
      within all(".wf-target").last do
        find("input.wf-url").set("https://example.com/filtered")

        # Rule 1: event_type in [bounce]
        click_button "+ Add Rule"
        within all(".wf-rule")[0] do
          find("input.wf-event-cb[value='bounce']").check
        end

        # Rule 2: source ends_with @myapp.com
        click_button "+ Add Rule"
        within all(".wf-rule")[1] do
          find("select.wf-field").find(:option, "From (source)").select_option
          find("select.wf-operator").find(:option, "ends with").select_option
          find("input.wf-value").set("@myapp.com")
        end
      end

      click_button "Create Project"

      project = SesDashboard::Project.last
      forwards = project.webhook_forwards
      rules = forwards[0]["rules"]
      expect(rules.length).to eq(2)
      expect(rules[0]).to eq("field" => "event_type", "operator" => "in", "value" => ["bounce"])
      expect(rules[1]).to eq("field" => "source", "operator" => "ends_with", "value" => "@myapp.com")
    end
  end

  describe "removing targets and rules" do
    it "removes a forward target from the UI before saving" do
      visit new_project_path

      fill_in "Name", with: "Remove Target Test"

      # Add two targets
      click_button "+ Add Forward Target"
      within all(".wf-target")[0] do
        find("input.wf-url").set("https://example.com/keep")
      end

      click_button "+ Add Forward Target"
      within all(".wf-target")[1] do
        find("input.wf-url").set("https://example.com/remove")
      end

      expect(all(".wf-target").count).to eq(2)

      # Remove the second target
      within all(".wf-target")[1] do
        click_button "Remove"
      end

      expect(all(".wf-target").count).to eq(1)

      click_button "Create Project"

      project = SesDashboard::Project.last
      expect(project.webhook_forwards.length).to eq(1)
      expect(project.webhook_forwards[0]["url"]).to eq("https://example.com/keep")
    end

    it "removes a rule from a target" do
      visit new_project_path

      fill_in "Name", with: "Remove Rule Test"

      click_button "+ Add Forward Target"
      within all(".wf-target").last do
        find("input.wf-url").set("https://example.com/hook")

        click_button "+ Add Rule"
        click_button "+ Add Rule"

        expect(all(".wf-rule").count).to eq(2)

        # Remove the first rule
        within all(".wf-rule")[0] do
          find("button", text: "\u00d7").click
        end

        expect(all(".wf-rule").count).to eq(1)
      end

      click_button "Create Project"

      project = SesDashboard::Project.last
      # Only the second rule (which became first after removal) should be saved
      # Since both were default event_type/in with no checkboxes, it should save with no rules
      expect(project.webhook_forwards.length).to eq(1)
    end
  end

  describe "clearing all forwards" do
    it "saves with no forwards when all targets are removed" do
      project = create(:ses_dashboard_project, name: "Clear Test")
      project.webhook_forwards = [
        { "url" => "https://example.com/old", "rules" => [] }
      ]
      project.save!

      visit edit_project_path(project)

      expect(all(".wf-target").count).to eq(1)

      within all(".wf-target").first do
        click_button "Remove"
      end

      expect(all(".wf-target").count).to eq(0)

      click_button "Update Project"

      project.reload
      expect(project.webhook_forwards).to eq([])
    end
  end

  describe "operator changes swap value input" do
    it "shows checkboxes for event_type + in, text input for source + contains" do
      visit new_project_path

      fill_in "Name", with: "Swap Test"
      click_button "+ Add Forward Target"

      within all(".wf-target").last do
        click_button "+ Add Rule"

        # Default: event_type + in → checkboxes should be visible
        within all(".wf-rule").last do
          expect(page).to have_css("input.wf-event-cb")
          expect(page).not_to have_css("input.wf-value")

          # Switch field to source → should swap to text input
          find("select.wf-field").find(:option, "From (source)").select_option

          expect(page).not_to have_css("input.wf-event-cb")
          expect(page).to have_css("input.wf-value")
        end
      end
    end
  end
end
