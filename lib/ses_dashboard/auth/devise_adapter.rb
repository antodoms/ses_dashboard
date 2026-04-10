module SesDashboard
  module Auth
    class DeviseAdapter < Base
      def initialize(app = nil, controller: nil)
        super(app)
        @controller = controller
      end

      def authenticate(request = nil)
        return false unless controller
        controller.authenticate_user!
        !controller.current_user.nil?
      rescue StandardError
        false
      end

      private

      attr_reader :controller
    end
  end
end
