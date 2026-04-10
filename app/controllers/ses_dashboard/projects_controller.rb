module SesDashboard
  class ProjectsController < ApplicationController
    before_action :set_project, only: [:show, :edit, :update, :destroy]

    def index
      @projects = Project.ordered
    end

    def show
      from = parse_date(params[:from]) || 30.days.ago.beginning_of_day
      to   = parse_date(params[:to])   || Time.current.end_of_day

      agg = StatsAggregator.new(project_id: @project.id, from: from, to: to)

      @counters     = agg.counters
      @total_opens  = agg.total_opens
      @total_clicks = agg.total_clicks
      @chart_data   = agg.time_series
      @from         = from
      @to           = to
    end

    def new
      @project = Project.new
    end

    def create
      @project = Project.new(project_params)
      if @project.save
        redirect_to project_path(@project), notice: "Project created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @project.update(project_params)
        redirect_to project_path(@project), notice: "Project updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @project.destroy
      redirect_to projects_path, notice: "Project deleted."
    end

    private

    def set_project
      @project = Project.find(params[:id])
    end

    def project_params
      params.require(:project).permit(:name, :description)
    end

    def parse_date(str)
      Time.zone.parse(str) if str.present?
    rescue ArgumentError
      nil
    end
  end
end
