Rails.application.routes.draw do
  # HTTP verb confusion: match with via: :all (brakeman flags this)
  match "products/search", to: "products#index", via: :all

  resources :products
  root "products#index"
end
