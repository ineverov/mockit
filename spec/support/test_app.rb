# frozen_string_literal: true

# spec/support/test_app.rb
require "rails"
require "action_controller/railtie"

module TestApp
  class Application < Rails::Application
    config.root = File.dirname(__FILE__)
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.secret_key_base = "test"
    config.hosts.clear

    # Insert the engine
    initializer :append_routes do |app|
      app.routes.append do
        get "/ping", to: ->(_env) { [200, { "Content-Type" => "text/plain" }, ["pong"]] }
        mount Mockit::Engine => "/mockit"
      end
    end
  end
end

Rails.application.configure do
  config.active_support.to_time_preserves_timezone = :zone
end
