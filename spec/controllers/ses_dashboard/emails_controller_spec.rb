require "rails_helper"

RSpec.describe SesDashboard::EmailsController, type: :controller do
  routes { SesDashboard::Engine.routes }

  before do
    SesDashboard.configure { |c| c.authentication_adapter = :none }
  end

  let(:project) { create(:ses_dashboard_project) }

  describe "GET #index" do
    it "returns 200 and paginates results" do
      create_list(:ses_dashboard_email, 3, project: project)
      get :index, params: { project_id: project.id }

      expect(response).to have_http_status(:ok)
      expect(SesDashboard::Email.where(project: project).count).to eq(3)
    end

    it "filters by status" do
      create(:ses_dashboard_email, project: project, status: "delivered")
      create(:ses_dashboard_email, project: project, status: "bounced")

      get :index, params: { project_id: project.id, status: "delivered" }

      expect(response).to have_http_status(:ok)
      expect(SesDashboard::Email.where(project: project, status: "delivered").count).to eq(1)
      expect(SesDashboard::Email.where(project: project, status: "bounced").count).to eq(1)
    end

    it "filters by search query" do
      create(:ses_dashboard_email, project: project, subject: "Invoice #1")
      create(:ses_dashboard_email, project: project, subject: "Newsletter")

      get :index, params: { project_id: project.id, q: "Invoice" }

      expect(response).to have_http_status(:ok)
      expect(SesDashboard::Email.search("Invoice").map(&:subject)).to include("Invoice #1")
      expect(SesDashboard::Email.search("Invoice").map(&:subject)).not_to include("Newsletter")
    end
  end

  describe "GET #export.csv" do
    it "returns a CSV file" do
      create(:ses_dashboard_email, project: project)
      get :export, params: { project_id: project.id, format: :csv }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
    end
  end
end
