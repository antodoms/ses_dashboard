module SesDashboard
  class TestEmailsController < ApplicationController
    before_action :set_project

    def new
      @from = SesDashboard.configuration.test_email_from
    end

    def create
      from    = params[:from].presence || SesDashboard.configuration.test_email_from
      to      = params[:to].presence
      subject = params[:subject].presence || "Test email from SES Dashboard"
      body    = params[:body].presence || "This is a test email sent via the SES Dashboard."

      unless from && to
        flash.now[:alert] = "From and To addresses are required."
        @from = from
        return render :new, status: :unprocessable_entity
      end

      begin
        ses_client = SesDashboard::Client.new
        ses_client.send_email(from: from, to: to, subject: subject, body: body)
        redirect_to project_path(@project), notice: "Test email sent to #{to}."
      rescue => e
        flash.now[:alert] = "Failed to send email: #{e.message}"
        @from = from
        render :new, status: :unprocessable_entity
      end
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end
  end
end
