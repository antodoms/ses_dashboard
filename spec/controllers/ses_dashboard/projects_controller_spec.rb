require "rails_helper"

RSpec.describe SesDashboard::ProjectsController, type: :controller do
  routes { SesDashboard::Engine.routes }

  before do
    SesDashboard.configure { |c| c.authentication_adapter = :none }
  end

  describe "GET #index" do
    it "returns 200 and lists projects" do
      create(:ses_dashboard_project, name: "Alpha")
      get :index
      expect(response).to have_http_status(:ok)
      expect(assigns(:projects).map(&:name)).to include("Alpha")
    end
  end

  describe "POST #create" do
    it "creates a project and redirects" do
      expect {
        post :create, params: { project: { name: "My Project", description: "desc" } }
      }.to change(SesDashboard::Project, :count).by(1)

      expect(response).to redirect_to(project_path(SesDashboard::Project.last))
    end

    it "re-renders new on invalid params" do
      post :create, params: { project: { name: "" } }
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE #destroy" do
    it "deletes the project" do
      project = create(:ses_dashboard_project)
      expect {
        delete :destroy, params: { id: project.id }
      }.to change(SesDashboard::Project, :count).by(-1)
      expect(response).to redirect_to(projects_path)
    end
  end
end
