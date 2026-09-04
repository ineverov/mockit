# frozen_string_literal: true

require_relative "mockit/version"

require "mockit/version"
require "mockit/distributed_lock"
require "mockit/known_mock_ids"
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
require "mockit/controllers/scenarios_controller"

# Base module for Mockit gem
module Mockit
  class Error < StandardError; end

  class << self
    attr_writer :logger, :storage

    # Mock id to fall back to when a request carries no X-Mockit-Id/X-Mock-Id
    # header of its own. Intended for a local single-developer server (e.g.
    # `Mockit.default_mock_id = "dev-default" if ENV["MOCKIT"] == "true"`) so
    # every request is mocked without hand-setting a header first. Unset
    # (nil) by default, meaning unheadered requests are left unmocked, same
    # as before this existed.
    attr_accessor :default_mock_id

    # Named, reusable override sets a host app registers at boot (e.g. from
    # its own config/initializers/mockit.rb), so the scenario-picker UI can
    # offer a dropdown per service instead of requiring hand-typed JSON every
    # time -- similar in spirit to picking a VCR cassette. `overrides` may be
    # a Hash (used as-is) or a zero-arg callable (Proc/lambda), resolved
    # fresh each time the scenario is applied -- use a callable when the
    # payload needs to be built at apply-time rather than baked in once at
    # boot (e.g. anything built from a factory). At most one scenario per
    # service should be `default: true` -- that's the one "reset to happy
    # path" re-applies.
    def register_scenario(service:, name:, overrides:, default: false)
      by_service = (@scenarios ||= {})[service.to_s] ||= {}

      if default
        existing_name, = by_service.find { |n, entry| entry[:default] && n != name.to_s }
        raise ArgumentError, "#{service} already has a default scenario (#{existing_name})" if existing_name
      end

      by_service[name.to_s] = { overrides: overrides, default: default }
    end

    # => { "scenario_name" => { overrides: Hash_or_callable, default: Boolean }, ... }
    def scenarios_for(service)
      (@scenarios || {})[service.to_s] || {}
    end

    # => "scenario_name" of the service's default scenario, or nil if none registered
    def default_scenario_name_for(service)
      scenarios_for(service).find { |_name, entry| entry[:default] }&.first
    end

    # All service names (strings) that have at least one registered scenario
    def known_services
      (@scenarios || {}).keys
    end

    # Resolve a named scenario's overrides to a plain Hash (calls it if it's
    # a callable). Raises ArgumentError if service/name isn't registered --
    # let the caller rescue and flash, don't silently return {}.
    def resolve_scenario(service:, name:)
      entry = scenarios_for(service)[name.to_s]
      raise ArgumentError, "No scenario named #{name} registered for service #{service}" unless entry

      overrides = entry[:overrides]
      overrides.respond_to?(:call) ? overrides.call : overrides
    end

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
