require "rails/all"

module LegacyBlog
  class Application < Rails::Application
    config.load_defaults 4.1 rescue nil
  end
end
