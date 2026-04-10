module SesDashboard
  module ApplicationHelper
    STATUS_BADGE_CLASSES = {
      "sent"       => "badge-sent",
      "delivered"  => "badge-delivered",
      "bounced"    => "badge-bounced",
      "complained" => "badge-complained",
      "rejected"   => "badge-rejected",
      "failed"     => "badge-failed"
    }.freeze

    def status_badge(status)
      css = STATUS_BADGE_CLASSES.fetch(status.to_s, "badge-unknown")
      content_tag(:span, status.to_s.capitalize, class: "badge #{css}")
    end

    def format_event_type(type)
      type.to_s.gsub("_", " ").capitalize
    end

    def webhook_url_for(project)
      ses_dashboard.webhook_url(project.token)
    end

    def format_destination(destination)
      Array(destination).join(", ")
    end

    def chart_data_tag(data)
      content_tag(:script, data.to_json.html_safe,
                  id: "chart-data", type: "application/json")
    end

    def date_range_link(label, days)
      from = days.days.ago.beginning_of_day
      to   = Time.current.end_of_day
      link_to label, request.path + "?from=#{from.iso8601}&to=#{to.iso8601}",
              class: "date-preset-link"
    end

    def pagination_link(label, page, params_override = {})
      return content_tag(:span, label, class: "pagination-disabled") unless page
      link_to label, request.path + "?" + request.query_parameters.merge(params_override.merge(page: page)).to_query,
              class: "pagination-link"
    end
  end
end
