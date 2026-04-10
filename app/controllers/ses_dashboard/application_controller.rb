module SesDashboard
  class ApplicationController < ActionController::Base
    protect_from_forgery with: :exception

    before_action :authenticate!

    helper SesDashboard::ApplicationHelper

    rescue_from ActiveRecord::RecordNotFound do
      respond_to do |format|
        format.html { render plain: "Not Found", status: :not_found }
        format.json { render json: { error: "Not Found" }, status: :not_found }
      end
    end

    private

    def authenticate!
      adapter = resolved_adapter
      return if adapter.nil?  # :none — open access

      unless adapter.authenticate(request)
        respond_to do |format|
          format.html do
            flash[:alert] = "You are not authorized to access this page."
            redirect_to main_app.root_path
          end
          format.json { render json: { error: "Unauthorized" }, status: :unauthorized }
        end
      end
    end

    def resolved_adapter
      case SesDashboard.configuration.authentication_adapter
      when :none       then nil
      when :devise     then Auth::DeviseAdapter.new(nil, controller: self)
      when :cloudflare then Auth::CloudflareAdapter.new
      else
        # Allow a custom adapter object/class to be set directly
        adapter = SesDashboard.configuration.authentication_adapter
        adapter.respond_to?(:authenticate) ? adapter : nil
      end
    end

    def current_project
      @current_project ||= Project.find(params[:project_id]) if params[:project_id]
    end
    helper_method :current_project
  end
end
