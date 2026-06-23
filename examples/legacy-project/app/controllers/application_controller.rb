class ApplicationController < ActionController::Base
  # CSRF protection intentionally disabled (brakeman flags this)
  # protect_from_forgery with: :exception
end
