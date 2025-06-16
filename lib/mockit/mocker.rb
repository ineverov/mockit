# frozen_string_literal: true

# Mockit module
module Mockit
  # Module handing wrapping original impementation with mocked one
  module Mocker
    def self.wrap(target_class, mock_module, service_key)
      # Instance methods wrapper
      instance_wrapper = Module.new
      wrap_methods(service_key, instance_wrapper, mock_module, mock_module)
      target_class.prepend(instance_wrapper)

      # Class methods wrapper
      singleton_wrapper = Module.new
      wrap_methods(service_key, singleton_wrapper, mock_module.singleton_class, mock_module)
      target_class.singleton_class.prepend(singleton_wrapper)
    end

    def self.wrap_methods(service_key, target, mod, mock_module)
      mock_methods = mod.instance_methods.grep(/^mock_/)

      mock_methods.each do |mock_name|
        real_name = mock_name.to_s.sub(/^mock_/, "").to_sym
        Mockit.logger.info "Redefining method #{real_name} with #{mock_name} implementation"
        # redefine real method
        redefine_method(target, real_name, service_key, mock_name)

        if mod.is_a?(Class)
          # copy over original mock method if this is a class
          target.define_method(mock_name) do |*args, **kwargs, &block|
            mock_module.method(mock_name).call(*args, **kwargs, &block)
          end
        else
          target.include(mod)
        end
      end
    end

    def self.redefine_method(target, real_name, service_key, mock_name) # rubocop:disable Metrics/MethodLength
      target.define_method(real_name) do |*args, **kwargs, &block|
        super_block = lambda do
          Mockit.logger.debug "Calling original method implementation for #{target}::#{real_name}"
          super(*args, **kwargs, &block)
        end

        if (override = Mockit::Store.read(service: service_key))

          send(mock_name, override, super_block, *args, **kwargs, &block)
        else
          super(*args, **kwargs, &block)
        end
      end
    end
  end
end
