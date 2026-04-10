Rails.application.routes.draw do
  mount SesDashboard::Engine, at: "/ses_dashboard"

  # Fallback root so engine redirects have somewhere to go in :none auth mode
  root to: proc { [200, { "Content-Type" => "text/plain" }, ["OK"]] }
end
