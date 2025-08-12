# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
require "simplecov"

SimpleCov.minimum_coverage 100
SimpleCov.refuse_coverage_drop :line
SimpleCov.start

# Ensure a minimal Sidekiq stub is available during Rails/Railtie initialization
unless defined?(Sidekiq)
  module Sidekiq
    class Config
      def client_middleware
        yield Chain.new
      end

      def server_middleware
        yield Chain.new
      end
    end

    class Chain
      def add(_); end
    end

    def self.configure_client
      yield Config.new if block_given?
    end

    def self.configure_server
      yield Config.new if block_given?
    end
  end
end

require "mockit"

require "rails"
require "request_store"
require "redis"

require_relative "support/test_app"
Rails.application.initialize!

require "rspec/rails"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"
  # config.include Rack::Test::Methods

  config.include Rails.application.routes.url_helpers

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  config.infer_spec_type_from_file_location!
  config.use_transactional_fixtures = true

  def app
    Rails.application
  end
end
