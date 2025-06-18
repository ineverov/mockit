# frozen_string_literal: true

# Mockit module
module Mockit
  # Module handing wrapping original impementation with mocked one
  module Mocker
    def self.wrap(target_class, mock_module, service_key)
      mock_instance_methods(target_class, mock_module, service_key)
      mock_singleton_methods(target_class, mock_module, service_key)
    end

    def self.mock_instance_methods(target_class, mock_module, service_key)
      meth_map = mock_module.instance_methods(false)
                            .grep(/^mock_/)
                            .to_h { |name| [name, mock_module.instance_method(name)] }
      target_class.prepend(wrap_methods(service_key, meth_map))
    end

    def self.mock_singleton_methods(target_class, mock_module, service_key)
      meth_map = mock_module.singleton_methods(false)
                            .grep(/^mock_/)
                            .to_h { |name| [name, mock_module.method(name).to_proc] }
      target_class.singleton_class.prepend(wrap_methods(service_key, meth_map))
    end

    def self.wrap_methods(service_key, mapping)
      wrapper = Module.new
      mapping.each do |name, meth|
        wrapper.define_method(name, meth)
        real_name = name.to_s.sub(/^mock_/, "").to_sym

        Mockit.logger.info "Redefining method #{real_name} with #{name} implementation"
        redefine_method(wrapper, real_name, service_key, name)
      end
      wrapper
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
