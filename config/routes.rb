Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Defines the root path route ("/")
  # root "posts#index"
  namespace :api do
    namespace :v1 do
      resource :company, only: %i[show update], controller: "companies"
      resources :company_signups, only: :create
      resources :users, only: %i[index show create update destroy]
      get "reservations", to: "reservations#index" # 会社単位・日付範囲で一覧
      resources :rooms, only: %i[index show create update destroy] do
        resources :reservations, only: %i[show create update destroy]
      end
      resource :session, only: %i[create destroy]
    end
  end
end
