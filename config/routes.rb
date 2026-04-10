SesDashboard::Engine.routes.draw do
  root to: "dashboard#index"

  resources :projects do
    resources :emails, only: [:index, :show] do
      collection do
        get :export
      end
    end
    resource :test_email, only: [:new, :create]
  end

  # SNS posts to this endpoint; authenticated by the project token in the URL,
  # not by the session-based auth applied to all other routes.
  post "webhook/:project_token", to: "webhooks#create", as: :webhook
end
