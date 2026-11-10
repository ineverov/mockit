# frozen_string_literal: true

require "spec_helper"
require "sidekiq/middleware/chain"

RSpec.describe Mockit::Railtie do
  it "inserts middleware and runs post initialize hooks" do
    # simulate an app with a middleware stack
    app = instance_double(TestApp::Application)
    middleware = instance_double(Rails::Configuration::MiddlewareStackProxy)
    allow(app).to receive(:middleware).and_return(middleware)

    expect(middleware).to receive(:insert_before).with(0, Mockit::Middleware::MockitIdMiddleware)
    expect(middleware).to receive(:insert_after).with(Mockit::Middleware::MockitIdMiddleware,
                                                      Mockit::Middleware::MappingFilter)

    # call the initializer block directly
    described_class.initializers.find { |i| i.name == "mockit.insert_middleware" }.run(app)
  end

  it "configures sidekiq when available and runs hooks" do
    # Ensure post-initialize hooks run without error
    expect do
      Mockit.run_post_initialize_hooks!
    end.not_to raise_error
  end

  it "runs configured blocks when configured before hooks" do
    ran = false
    Mockit.configure do |_m|
      ran = true
    end

    # calling the runner should execute the configured block
    Mockit.run_post_initialize_hooks!
    expect(ran).to be true
  end

  describe ".configure_sidekiq" do
    it "runs the server middleware outside middleware registered before it, so the mock id outlives the job body" do
      mock_id_after_job = :not_called
      # Stands in for Sidekiq::Batch::Server: added at gem load, pushes the batch callback after the job body.
      batch_server = Class.new do
        define_method(:call) do |_job_instance, _job, _queue, &block|
          block.call
          mock_id_after_job = Mockit::Store.current_mock_id
        end
      end
      chain = Sidekiq::Middleware::Chain.new
      chain.add batch_server
      config = instance_double(Sidekiq::Config, client_middleware: nil)
      allow(config).to receive(:server_middleware).and_yield(chain)
      allow(Sidekiq).to receive(:configure_client)
      allow(Sidekiq).to receive(:configure_server).and_yield(config)

      described_class.configure_sidekiq
      chain.invoke(Object.new, { "mockit_id" => "batch-mock-id" }, "default") { nil }

      expect(mock_id_after_job).to eq("batch-mock-id")
    end
  end
end
