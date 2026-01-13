# frozen_string_literal: true

Mockit::Engine.routes.draw do
  post "/mocks", to: "mocks#create"
  get  "/mocks", to: "mocks#show"
  delete "/mocks", to: "mocks#destroy"
  delete "/mocks/teardown", to: "mocks#destroy_all"
  post "/map_request", to: "mocks#create_mapping"
end
