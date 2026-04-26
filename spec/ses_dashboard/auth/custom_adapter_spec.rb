require "spec_helper"

RSpec.describe "custom authentication adapter" do
  let(:adapter_class) do
    Class.new(SesDashboard::Auth::Base) do
      def authenticate(request)
        user_id = request.session[:user_id]
        logged_in_at = request.session[:logged_in_at]

        return false unless user_id.present? && logged_in_at
        logged_in_at > 12.hours.ago
      end
    end
  end

  let(:adapter) { adapter_class.new }

  def mock_request(session = {})
    instance_double(Rack::Request, session: session)
  end

  describe "#authenticate" do
    it "returns true when session has a valid user_id and recent logged_in_at" do
      request = mock_request(user_id: 1, logged_in_at: 1.hour.ago)
      expect(adapter.authenticate(request)).to be true
    end

    it "returns false when user_id is missing" do
      request = mock_request(logged_in_at: 1.hour.ago)
      expect(adapter.authenticate(request)).to be false
    end

    it "returns false when logged_in_at is missing" do
      request = mock_request(user_id: 1)
      expect(adapter.authenticate(request)).to be false
    end

    it "returns false when session is expired" do
      request = mock_request(user_id: 1, logged_in_at: 13.hours.ago)
      expect(adapter.authenticate(request)).to be false
    end
  end

  describe "registration via SesDashboard.configure" do
    it "accepts a custom adapter instance" do
      SesDashboard.configure { |c| c.authentication_adapter = adapter }
      expect(SesDashboard.configuration.authentication_adapter).to eq(adapter)
    end

    it "accepts an adapter defined inline with Class.new" do
      inline_adapter = Class.new(SesDashboard::Auth::Base) do
        def authenticate(_request) = true
      end

      SesDashboard.configure { |c| c.authentication_adapter = inline_adapter.new }
      expect(SesDashboard.configuration.authentication_adapter).to respond_to(:authenticate)
    end
  end
end
