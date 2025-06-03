# frozen_string_literal: true

require "rails"

module Mockit
  # Rails railtie
  class Railtie < Rails::Railtie
    initializer "mockit.insert_middleware" do |app|
      app.middleware.insert_before 0, Mockit::Middleware::RequestStore
    end

    config.after_initialize do
      if defined?(Sidekiq)
        Sidekiq.configure_client do |config|
          config.client_middleware { |chain| chain.add Mockit::Middleware::SidekiqClient }
        end

        Sidekiq.configure_server do |config|
          config.client_middleware { |chain| chain.add Mockit::Middleware::SidekiqClient }
          config.server_middleware { |chain| chain.add Mockit::Middleware::SidekiqServer }
        end
      end
    end
  end
end
