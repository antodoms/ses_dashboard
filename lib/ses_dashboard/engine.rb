if defined?(Rails)
  module SesDashboard
    class Engine < ::Rails::Engine
      isolate_namespace SesDashboard
    end
  end
end
