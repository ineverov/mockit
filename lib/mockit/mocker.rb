# frozen_string_literal: true

# Mockit module
module Mockit
  # Module handing wrapping original impementation with mocked one
  module Mocker
    def self.wrap(target_class, mock_module, service_key)
      # Helper to wrap methods for prepend module
      wrap_methods = wrap_methods_lambda(service_key)

      # Instance methods wrapper
      instance_wrapper = Module.new
      wrap_methods.call(instance_wrapper, mock_module)
      target_class.prepend(instance_wrapper)

      # Class methods wrapper
      singleton_wrapper = Module.new
      wrap_methods.call(singleton_wrapper, mock_module.singleton_class)
      target_class.singleton_class.prepend(singleton_wrapper)
    end
  end

  def self.wrap_methods_lambda(service_key)
    lambda do |target, mod|
      mock_methods = mod.instance_methods.grep(/^mock_/)

      mock_methods.each do |mock_method|
        real_method = mock_method.to_s.sub(/^mock_/, "").to_sym
        redefine_method(target, real_method, service_key)
      end
    end
  end

  def self.redefine_method(target, real_method, service_key)
    target.define_method(real_method) do |*args, **kwargs, &block|
      override = Mockit::Store.read(service: service_key)
      if override
        super_method = -> { super(*args, **kwargs, &block) }
        mod.instance_method(mock_method).bind(self).call(override, super_method, *args, **kwargs, &block)
      else
        super(*args, **kwargs, &block)
      end
    end
  end
end
