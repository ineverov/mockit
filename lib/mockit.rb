# frozen_string_literal: true

require_relative "mockit/version"

require "mockit/version"
require "mockit/store"
require "mockit/railtie"
require "mockit/engine"
require "mockit/mocker"
require "mockit/mock_context"

require "mockit/middleware/mockid_id_middleware"
require "mockit/middleware/sidekiq_client"
require "mockit/middleware/sidekiq_server"
require "mockit/middleware/mapping_filter"
require "mockit/middleware/mapping_matcher"

require "mockit/controllers/mocks_controller"

# Base module for Mockit gem
module Mockit
  class Error < StandardError; end

  class << self
    attr_writer :logger, :storage

    # Configure mocking for a set of classes.
    #
    # @param mocking_map [Hash] map of Class => mock module
    # @example
    #   Mockit.mock_classes(FooClient: FooClientMock)
    def mock_classes(**mocking_map)
      mocking_map.each do |klass, mock_module|
        next unless mock_module

        Mockit.logger.info "Mocking class #{klass} with #{mock_module}"

        Mocker.wrap(klass, mock_module, extract_service_key(klass))
      end
    end

    # Run any blocks registered via `Mockit.configure`.
    # Called by the Railtie `after_initialize` hook.
    def run_post_initialize_hooks!
      (@config_blocks || []).each do |block|
        block.call(self)
      end
    end

    # Register a configuration block to be run during initialization.
    # Blocks receive the `Mockit` module as an argument.
    #
    # @example
    #   Mockit.configure do |m|
    #     m.mock_classes(MyClient: MyClientMock)
    #   end
    def configure(&block)
      @config_blocks ||= []
      @config_blocks << block
    end

    def logger
      @logger ||= Logger.new($stdout)
    end

    def storage
      @storage ||= Rails.cache
    end

    private

    def extract_service_key(client_class)
      client_class.name.underscore.to_sym
    end
  end
end
