# frozen_string_literal: true

module Mockit
  # Rails engine adding mock write/read endpoints from MockitController
  class Engine < ::Rails::Engine
    isolate_namespace Mockit
  end
end
