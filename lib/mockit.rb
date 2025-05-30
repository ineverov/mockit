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

module Mockit
  class Error < StandardError; end

  def self.mock_classes(*client_classes)
    client_classes.each do |client_class|
      mock_module = resolve_mock_module(client_class)
      next unless mock_module

      service_key = extract_service_key(client_class)
      BaseMocker.wrap(client_class, mock_module, service_key)
    end
  end

  private_class_method def self.resolve_mock_module(client_class)
    mock_module_name = "Mockit::Mock::#{client_class.name.demodulize}"
    mock_module_name.safe_constantize
  end

  private_class_method def self.extract_service_key(client_class)
    client_class.name.demodulize.underscore.to_sym
  end
end
