Rails.application.routes.draw do
  # HTTP verb confusion: match with via: :all (brakeman flags this)
  match "posts/search", to: "posts#index", via: :all

  resources :posts
  root "posts#index"
end
