Rails.application.routes.draw do
  mount SesDashboard::Engine, at: "/"
end
