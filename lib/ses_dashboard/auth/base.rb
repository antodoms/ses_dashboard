require "rack"
require "json"

module SesDashboard
  module Auth
    class Base
      def initialize(app = nil)
        @app = app
      end

      def authenticate(request = nil)
        raise NotImplementedError, "Auth adapter must implement authenticate(request)"
      end

      def call(env)
        request = Rack::Request.new(env)
        if authenticate(request)
          @app.call(env)
        else
          unauthorized_response
        end
      end

      private

      def unauthorized_response
        [401, { "Content-Type" => "application/json" }, [{ error: "Unauthorized" }.to_json]]
      end
    end
  end
end
