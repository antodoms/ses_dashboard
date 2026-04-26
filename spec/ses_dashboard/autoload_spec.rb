require "spec_helper"

# Verifies that requiring "ses/dashboard" (the path Bundler derives from the
# hyphenated gem name "ses-dashboard") correctly loads the SesDashboard module.
RSpec.describe "gem auto-require" do
  it "loads SesDashboard via the ses/dashboard shim path" do
    expect(defined?(SesDashboard)).to eq("constant")
  end

  it "loads SesDashboard::Engine via the shim path" do
    expect(defined?(SesDashboard::Engine)).to eq("constant")
  end

  it "exposes the configure DSL" do
    expect(SesDashboard).to respond_to(:configure)
  end
end
