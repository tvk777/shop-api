Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  devise_for :users,
             path: "",
             path_names: { sign_in: "login", sign_out: "logout", registration: "signup" },
             controllers: { sessions: "users/sessions", registrations: "users/registrations" }
  namespace :admin do
    resources :users, only: [ :index, :show, :update ]
    resources :items
  end
  resource :profile, only: [ :show, :update ]
  resources :items, only: [ :index ]
  resources :orders, only: [ :index, :show, :create ]
end
