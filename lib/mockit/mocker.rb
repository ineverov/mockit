# frozen_string_literal: true

# Mockit module
module Mockit
  # Module handing wrapping original impementation with mocked one
  module Mocker
    # Prepend methods to a class to use mock implementations when overrides exist.
    #
    # @param target_class [Class] class to wrap
    # @param mock_module [Module] module providing `mock_` prefixed methods
    # @param service_key [Symbol] key used to lookup overrides in the store
    def self.wrap(target_class, mock_module, service_key)
      mock_instance_methods(target_class, mock_module, service_key)
      mock_singleton_methods(target_class, mock_module, service_key)
    end

    def self.mock_instance_methods(target_class, mock_module, service_key)
      method_map = mock_module.instance_methods(false)
                              .grep(/^mock_/)
                              .to_h do |name|
                                um = mock_module.instance_method(name)
                                [name, { meth: um, singleton: false, has_kw: accepts_keyword_args?(um) }]
      end

      target_class.prepend(wrap_methods(service_key, method_map, mock_module))
    end

    def self.mock_singleton_methods(target_class, mock_module, service_key)
      method_map = mock_module.singleton_methods(false)
                              .grep(/^mock_/)
                              .to_h do |name|
                                m = mock_module.method(name)
                                [name, { meth: m.to_proc, singleton: true, has_kw: accepts_keyword_args?(m) }]
      end

      target_class.singleton_class.prepend(wrap_methods(service_key, method_map, mock_module))
    end

    def self.wrap_methods(service_key, method_map, mock_module)
      wrapper = Module.new
      # If there are instance mocks, include the mock module so helper
      # instance methods (without `mock_` prefix) are available to the
      # target instance when mock methods run.
      wrapper.include(mock_module) if instance_methods?(method_map)

      method_map.each do |name, info|
        wrap_method(wrapper, name, info[:meth], info[:singleton])

        redefine_original_method(wrapper, service_key, name, has_kw: info[:has_kw])
      end
      wrapper
    end

    def self.instance_methods?(method_map)
      method_map.values.any? { |info| info[:singleton] == false }
    end

    def self.wrap_method(wrapper, name, callable, singleton)
      # For instance mocks we have an UnboundMethod we can bind to
      # the instance. For singleton mocks we store a Proc (method.to_proc)
      # which we call with the usual arguments; the Proc will receive
      # the target class as the first parameter when invoked by
      # `redefine_method`.
      if singleton
        wrap_singleton_method(wrapper, name, callable)
      else
        # For instance-level mock methods we stored an UnboundMethod.
        # Bind it to the instance and invoke with whatever args/kwargs
        # the test or caller provided.
        wrap_instance_method(wrapper, name, callable)
      end
    end

    def self.wrap_singleton_method(wrapper, name, callable)
      wrapper.define_method(name) do |*a, **kw, &blk|
        callable.call(*a, **kw, &blk)
      end
    end

    def self.wrap_instance_method(wrapper, name, callable)
      wrapper.define_method(name) do |*a, **kw, &blk|
        bound = callable.bind(self)
        bound.call(*a, **kw, &blk)
      end
    end

    # Redefine a method to dispatch to the mock version when overrides exist.
    # The mock method receives the stored overrides and a `super_block` to call
    # the original implementation if needed.
    def self.redefine_original_method(target, service_key, mock_name, has_kw: false)
      public_name = mock_name.to_s.sub(/^mock_/, "").to_sym

      Mockit.logger.info(
        "Redefining method #{public_name} with #{mock_name} implementation"
      )

      target.define_method(
        public_name,
        create_original_method_body(target, public_name, service_key, mock_name, has_kw)
      )
    end

    def self.create_original_method_body(target, public_name, service_key, mock_name, has_kw) # rubocop:disable Metrics/MethodLength
      proc do |*args, **kwargs, &block|
        super_block = proc do
          Mockit.logger.debug("Calling original method implementation for #{target}::#{public_name}")
          super(*args, **kwargs, &block)
        end
        if (override = Mockit::Store.read(service: service_key))
          # Provide a structured context that mock implementations can
          # optionally accept via keyword arg `mock_context:`. This keeps
          # the public API flexible and avoids forcing positional args.
          ctx = Mockit::Mocker.build_ctx(self, override, super_block, args, kwargs, block)

          # If the mock method accepts keyword args, dispatch accordingly.
          Mockit::Mocker.handle_override(self, mock_name, has_kw, ctx)
        else
          super(*args, **kwargs, &block)
        end
      end
    end

    def self.build_ctx(instance, override, super_block, args, kwargs, block) # rubocop:disable Metrics/ParameterLists
      Mockit::MockContext.new(
        target: instance, overrides: override, super_block: super_block,
        args: args, kwargs: kwargs, block: block
      )
    end

    def self.handle_override(instance, mock_name, has_kw, ctx)
      if has_kw
        instance.send(mock_name, mock_context: ctx)
      else
        instance.send(mock_name, ctx.overrides, ctx.super_block, *ctx.args, **ctx.kwargs, &ctx.block)
      end
    end

    # Helper to detect if a Method/UnboundMethod accepts keyword args.
    def self.accepts_keyword_args?(method_like)
      new_syntax = method_like.parameters.all? do |type, name|
        (%i[key keyreq].include?(type) && name == :mock_context) || %i[keyrest].include?(type)
      end

      Mockit.logger.warn(<<~DEPRECATION) unless new_syntax
        Mockit Deprecation: #{method_like}#: Calling mock methods with positional args is deprecated. Use `mock_context:` keyword and accept a Mockit::MockContext instead. This will be removed in the next minor version
      DEPRECATION

      new_syntax
    end
  end
end
