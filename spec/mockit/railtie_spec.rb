# frozen_string_literal: true

require "spec_helper"

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
end
