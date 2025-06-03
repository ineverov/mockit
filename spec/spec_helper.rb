# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"

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
