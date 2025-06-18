# frozen_string_literal: true

require_relative "mockit/version"

require "mockit/version"
require "mockit/store"
require "mockit/railtie"
require "mockit/engine"
require "mockit/mocker"

require "mockit/middleware/request_store"
require "mockit/middleware/sidekiq_client"
require "mockit/middleware/sidekiq_server"
require "mockit/controllers/mocks_controller"

# Base module for Mockit gem
module Mockit
  class Error < StandardError; end

  class << self
    attr_writer :logger, :storage

    def mock_classes(**mocking_map)
      mocking_map.each do |klass, mock_module|
        next unless mock_module

        Mockit.logger.info "Mocking class #{klass} with #{mock_module}"

        Mocker.wrap(klass, mock_module, extract_service_key(klass))
      end
    end

    def run_post_initialize_hooks!
      (@config_blocks || []).each do |block|
        block.call(self)
      end
    end

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
