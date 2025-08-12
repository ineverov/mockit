# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit do
  let(:client_class) do
    Class.new do
      def inst_method(*_args)
        "original_instance_method"
      end

      def other_instance_method(*_args)
        "other_original_instance_method"
      end

      def self.snglton_method(*_args)
        "original_singleton_method"
      end

      def self.other_singleton_method(*_args)
        "other_original_singleton_method"
      end
    end
  end

  let(:mock_module) do
    Module.new do
      def mock_inst_method(overrides, super_block, *args)
        [super_block.call, overrides, args]
      end

      def self.mock_snglton_method(overrides, super_block, *args)
        [super_block.call, overrides, args]
      end
    end
  end

  let(:instance) do
    client_class.new
  end

  before do
    described_class.logger = Logger.new(File::NULL)
    RequestStore.store[:mockit_id] = "a123b"
    allow(client_class).to receive(:name).and_return("Module::ClassName")
    described_class.mock_classes(client_class => mock_module)
  end

  after do
    RequestStore.clear!
    described_class.storage.clear
  end

  it "redefines methods" do
    expect(instance).to respond_to(:inst_method)
    expect(instance).to respond_to(:mock_inst_method)
    expect(instance).not_to respond_to(:mock_other_instance_method)

    expect(client_class).to respond_to(:snglton_method)
    expect(client_class).to respond_to(:mock_snglton_method)
    expect(client_class).not_to respond_to(:mock_other_singleton_method)
  end

  context "without overrides for service" do
    before do
      Mockit::Store.write(service: "module/different_class_name", overrides: { key: true })
    end

    it "calls original methods" do
      expect(instance.inst_method(1)).to eq("original_instance_method")
      expect(instance.other_instance_method(2)).to eq("other_original_instance_method")
      expect(client_class.snglton_method(1)).to eq("original_singleton_method")
      expect(client_class.other_singleton_method(2)).to eq("other_original_singleton_method")
    end
  end

  context "with overrides set" do
    it "calls mock method" do
      Mockit::Store.write(service: "module/class_name", overrides: { key: true })
      expect(instance.inst_method(1)).to eq(["original_instance_method", { "key" => true }, [1]])
      expect(instance.other_instance_method(2)).to eq("other_original_instance_method")

      expect(client_class.snglton_method(1)).to eq(["original_singleton_method", { "key" => true }, [1]])
      expect(client_class.other_singleton_method(2)).to eq("other_original_singleton_method")
    end
  end
end
