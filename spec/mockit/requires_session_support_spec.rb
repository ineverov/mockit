# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::RequiresSessionSupport do
  # A bare host, not an ActionController::Base, so this exercises the
  # concern's own logic without booting a full Rails dispatch cycle --
  # `prepend_before_action` only needs to be callable at include time.
  let(:harness_class) do
    Class.new do
      def self.prepend_before_action(*); end

      include Mockit::RequiresSessionSupport

      attr_accessor :request, :rendered

      def render(**opts)
        self.rendered = opts
      end
    end
  end
  let(:harness) { harness_class.new }

  def fake_request(session_enabled:, with_flash: true)
    session = instance_double(ActionDispatch::Request::Session, enabled?: session_enabled)
    stubs = { session: session }
    stubs[:flash] = {} if with_flash
    instance_double(ActionDispatch::Request, **stubs)
  end

  describe "#ensure_session_support!" do
    it "renders the missing-session message when the request has no flash method (config.api_only = true)" do
      harness.request = fake_request(session_enabled: true, with_flash: false)

      harness.send(:ensure_session_support!)

      expect(harness.rendered).to eq(
        plain: described_class::MISSING_SESSION_MESSAGE,
        status: :internal_server_error
      )
    end

    it "renders the missing-session message when the session itself is disabled" do
      harness.request = fake_request(session_enabled: false)

      harness.send(:ensure_session_support!)

      expect(harness.rendered).to eq(
        plain: described_class::MISSING_SESSION_MESSAGE,
        status: :internal_server_error
      )
    end

    it "does nothing when the host app has both flash and an enabled session" do
      harness.request = fake_request(session_enabled: true)

      harness.send(:ensure_session_support!)

      expect(harness.rendered).to be_nil
    end
  end
end
