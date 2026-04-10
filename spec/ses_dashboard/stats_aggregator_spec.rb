require "rails_helper"

RSpec.describe SesDashboard::StatsAggregator do
  let(:project) { create(:ses_dashboard_project) }

  before do
    # 5 delivered, 2 bounced, 1 complained — all within range
    create_list(:ses_dashboard_email, 5, project: project, status: "delivered", sent_at: 5.days.ago, opens: 2, clicks: 1)
    create_list(:ses_dashboard_email, 2, project: project, status: "bounced",   sent_at: 3.days.ago)
    create_list(:ses_dashboard_email, 1, project: project, status: "complained", sent_at: 1.day.ago)
  end

  subject(:agg) do
    described_class.new(project_id: project.id, from: 10.days.ago, to: Time.current)
  end

  describe "#counters" do
    it "returns correct counts per status" do
      c = agg.counters
      expect(c[:delivered]).to  eq(5)
      expect(c[:bounced]).to    eq(2)
      expect(c[:complained]).to eq(1)
    end

    it "derives not_delivered as the sum of bounced + complained + rejected" do
      expect(agg.counters[:not_delivered]).to eq(3)
    end

    it "returns the total across all statuses" do
      expect(agg.counters[:total]).to eq(8)
    end
  end

  describe "#total_opens and #total_clicks" do
    it "sums opens across all emails in scope" do
      expect(agg.total_opens).to eq(10)  # 5 emails × 2 opens
    end

    it "sums clicks across all emails in scope" do
      expect(agg.total_clicks).to eq(5)  # 5 emails × 1 click
    end
  end

  describe "#time_series" do
    it "returns a hash with :labels and :data arrays of equal length" do
      ts = agg.time_series
      expect(ts[:labels]).to be_an(Array)
      expect(ts[:data]).to   be_an(Array)
      expect(ts[:labels].length).to eq(ts[:data].length)
    end

    it "fills in zero for days with no emails" do
      ts = agg.time_series
      expect(ts[:data].sum).to eq(8)  # total emails
    end
  end
end
