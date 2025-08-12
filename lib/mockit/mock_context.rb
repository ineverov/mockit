# frozen_string_literal: true

module Mockit
  MockContext = Struct.new(:target, :overrides, :super_block, :args, :kwargs, :block)
end
