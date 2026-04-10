module SesDashboard
  # Aggregates email statistics for the dashboard.
  #
  # Usage:
  #   agg = StatsAggregator.new(project_id: project.id, from: 14.days.ago, to: Time.current)
  #   agg.counters       # => { sent: 100, delivered: 90, bounced: 3, ... }
  #   agg.time_series    # => { labels: ["2024-01-01", ...], data: [5, 12, ...] }
  #   agg.total_opens    # => 45
  #   agg.total_clicks   # => 12
  #
  class StatsAggregator
    def initialize(project_id: nil, from: nil, to: nil)
      @project_id = project_id
      @from       = from
      @to         = to
    end

    # Returns counts grouped by status.
    # "not_delivered" is derived as the sum of bounced + complained + rejected.
    def counters
      scope = base_scope
      counts = scope.group(:status).count

      not_delivered = (counts["bounced"] || 0) +
                      (counts["complained"] || 0) +
                      (counts["rejected"] || 0)

      {
        total:         scope.count,
        sent:          counts["sent"] || 0,
        delivered:     counts["delivered"] || 0,
        bounced:       counts["bounced"] || 0,
        complained:    counts["complained"] || 0,
        rejected:      counts["rejected"] || 0,
        failed:        counts["failed"] || 0,
        not_delivered: not_delivered
      }
    end

    def total_opens
      base_scope.sum(:opens)
    end

    def total_clicks
      base_scope.sum(:clicks)
    end

    # Returns a Chart.js-compatible hash: { labels: [...], data: [...] }
    # Groups by calendar day over the from..to range, filling gaps with zero.
    def time_series
      from = effective_from
      to   = effective_to

      expr = Arel.sql(date_group_expr)
      raw = base_scope
              .where(sent_at: from..to)
              .group(expr)
              .order(expr)
              .count

      all_days = date_range_days(from, to)
      labels   = all_days.map { |d| d.strftime("%Y-%m-%d") }
      data     = all_days.map { |d| raw[d.strftime("%Y-%m-%d")] || 0 }

      { labels: labels, data: data }
    end

    private

    def base_scope
      scope = SesDashboard::Email.all
      scope = scope.where(project_id: @project_id) if @project_id
      scope = scope.where(sent_at: @from..@to)     if @from && @to
      scope
    end

    def date_group_expr
      case connection.adapter_name.downcase
      when "sqlite"
        "strftime('%Y-%m-%d', sent_at)"
      when "postgresql"
        "TO_CHAR(sent_at AT TIME ZONE 'UTC', 'YYYY-MM-DD')"
      else
        # MySQL / MariaDB
        "DATE_FORMAT(sent_at, '%Y-%m-%d')"
      end
    end

    def connection
      ActiveRecord::Base.connection
    end

    def effective_from
      @from || 30.days.ago.beginning_of_day
    end

    def effective_to
      @to || Time.current.end_of_day
    end

    def date_range_days(from, to)
      from_d = from.to_date
      to_d   = to.to_date
      (from_d..to_d).to_a
    end
  end
end
