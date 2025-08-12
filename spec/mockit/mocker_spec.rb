# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Mocker do
  let(:simple_client_class) do
    Class.new do
      def method_one(name)
        [self.class, name]
      end

      def method_two(name)
        [self.class, name]
      end

      def self.singleton_method_one(name)
        [self, name]
      end

      def other_method
        "other_method_result"
      end

      def self.other_method
        "other_singleton_method_result"
      end
    end
  end

  before do
    stub_const("SimpleClient", simple_client_class)
    stub_const("SimpleMock", simple_mock_module)

    Mockit::Store.mock_id = "mocker-1"
    Mockit::Store.delete_all

    described_class.wrap(SimpleClient, SimpleMock, :simple_client)
  end

  context "when using old mockit syntax (deprecated)" do
    let(:simple_mock_module) do
      Module.new do
        def mock_method_one(overrides, super_block, name)
          [self.class, overrides, super_block.call, name, helper_method_in_mock]
        end

        def self.mock_singleton_method_one(overrides, super_block, name)
          [self, overrides, super_block.call, name, helper_method_in_mock]
        end

        def helper_method_in_mock
          "helper_method_in_mock"
        end

        def self.helper_method_in_mock
          "singleton helper method in mock"
        end
      end
    end

    it "wraps instance and singleton methods and falls back to original" do
      # no overrides present -> original behavior
      expect(SimpleClient.new.method_one("you")).to eq([SimpleClient, "you"])
      expect(SimpleClient.singleton_method_one("you")).to eq([SimpleClient, "you"])

      # with overrides present
      Mockit::Store.write(service: :simple_client, overrides: { "data" => "x" })

      expect(SimpleClient.new.method_one("you")).to eq([SimpleClient, { "data" => "x" }, [SimpleClient, "you"], "you",
                                                        "helper_method_in_mock"])

      expect(SimpleClient.singleton_method_one("you")).to eq([SimpleMock, { "data" => "x" }, [SimpleClient, "you"],
                                                              "you", "singleton helper method in mock"])
    end
  end

  context "when using new mock_context keyword" do
    let(:simple_mock_module) do
      Module.new do
        def mock_method_one(mock_context:)
          mock_context = mock_context.to_h.with_indifferent_access
          mock_context[:other] = mock_context[:target].other_method
          mock_context[:target_class] = mock_context.delete(:target).class
          mock_context[:super_block_result] = mock_context.delete(:super_block).call
          mock_context[:helper] = helper_method_in_mock
          mock_context
        end

        def self.mock_singleton_method_one(mock_context:)
          mock_context = mock_context.to_h.with_indifferent_access
          mock_context[:other] = mock_context[:target].other_method
          mock_context[:super_block_result] = mock_context.delete(:super_block).call
          mock_context[:helper] = helper_method_in_mock

          mock_context
        end

        def helper_method_in_mock
          "helper method"
        end

        def self.helper_method_in_mock
          "singleton helper method"
        end
      end
    end

    it "wraps instance and singleton methods and falls back to original" do
      # no override present -> original behavior
      block = -> { true }
      expect(SimpleClient.new.method_one("you", &block)).to eq([SimpleClient, "you"])
      expect(SimpleClient.new.method_two("you", &block)).to eq([SimpleClient, "you"])
      expect(SimpleClient.singleton_method_one("you", &block)).to eq([SimpleClient, "you"])

      # with override present
      Mockit::Store.write(service: :simple_client, overrides: { "data" => "x" })

      expect(SimpleClient.new.method_one("you", &block)).to eq({
        args: ["you"],
        helper: "helper method",
        kwargs: {},
        block: block,
        overrides: { "data" => "x" },
        super_block_result: [SimpleClient, "you"],
        other: "other_method_result",
        target_class: SimpleClient
      }.with_indifferent_access)

      expect(SimpleClient.singleton_method_one("you", &block)).to eq({
        args: ["you"],
        helper: "singleton helper method",
        other: "other_singleton_method_result",
        kwargs: {},
        block: block,
        overrides: { "data" => "x" },
        super_block_result: [SimpleClient, "you"],
        target: SimpleClient
      }.with_indifferent_access)
    end
  end
end
