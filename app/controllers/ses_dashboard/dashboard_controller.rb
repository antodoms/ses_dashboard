module SesDashboard
  class DashboardController < ApplicationController
    def index
      from = parse_date(params[:from]) || 30.days.ago.beginning_of_day
      to   = parse_date(params[:to])   || Time.current.end_of_day

      agg = StatsAggregator.new(from: from, to: to)

      @counters     = agg.counters
      @total_opens  = agg.total_opens
      @total_clicks = agg.total_clicks
      @chart_data   = agg.time_series
      @projects     = Project.ordered
      @from         = from
      @to           = to
    end

    private

    def parse_date(str)
      Time.zone.parse(str) if str.present?
    rescue ArgumentError
      nil
    end
  end
end
