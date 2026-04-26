require "spec_helper"

RSpec.describe SesDashboard::Engine do
  it "is registered as a Rails engine" do
    expect(Rails.application.railties.map(&:class)).to include(SesDashboard::Engine)
  end

  it "isolates its namespace" do
    expect(SesDashboard::Engine.isolated?).to be true
  end
end
