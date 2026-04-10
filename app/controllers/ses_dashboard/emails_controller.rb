require "csv"

module SesDashboard
  class EmailsController < ApplicationController
    before_action :set_project

    def index
      scope = filtered_scope
      @emails, @pagination = Paginatable.paginate(scope, page: params[:page])

      respond_to do |format|
        format.html
        format.json { render json: serialize_emails(@emails) }
      end
    end

    def show
      @email  = @project.emails.find(params[:id])
      @events = @email.email_events.ordered
    end

    def export
      scope = filtered_scope

      respond_to do |format|
        format.csv do
          send_data generate_csv(scope), filename: "emails-#{Date.today}.csv", type: "text/csv"
        end
        format.json do
          send_data serialize_emails(scope).to_json,
                    filename: "emails-#{Date.today}.json",
                    type: "application/json"
        end
      end
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end

    def filtered_scope
      scope = @project.emails.ordered
      scope = scope.search(params[:q])
      scope = scope.by_status(params[:status])
      scope = scope.in_date_range(
        parse_date(params[:from_date]),
        parse_date(params[:to_date])
      )
      scope
    end

    def parse_date(str)
      Time.zone.parse(str) if str.present?
    rescue ArgumentError
      nil
    end

    def generate_csv(scope)
      CSV.generate(headers: true) do |csv|
        csv << %w[message_id source subject destination status opens clicks sent_at]
        scope.each do |email|
          csv << [
            email.message_id,
            email.source,
            email.subject,
            Array(email.destination).join("; "),
            email.status,
            email.opens,
            email.clicks,
            email.sent_at&.iso8601
          ]
        end
      end
    end

    def serialize_emails(emails)
      emails.map do |e|
        {
          message_id:  e.message_id,
          source:      e.source,
          subject:     e.subject,
          destination: e.destination,
          status:      e.status,
          opens:       e.opens,
          clicks:      e.clicks,
          sent_at:     e.sent_at&.iso8601
        }
      end
    end
  end
end
