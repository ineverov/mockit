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

    def mock_classes(*client_classes)
      client_classes.each do |client_class|
        Mockit.logger.info "Mocking class #{client_class}"
        mock_module = resolve_mock_module(client_class)
        next unless mock_module

        service_key = extract_service_key(client_class)
        Mocker.wrap(client_class, mock_module, service_key)
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

    def resolve_mock_module(client_class)
      mock_module_name = "Mockit::Mock::#{client_class.name.demodulize}"
      mock_module_name.safe_constantize
    end

    def extract_service_key(client_class)
      client_class.name.demodulize.underscore.to_sym
    end
  end
end
