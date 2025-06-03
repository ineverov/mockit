# frozen_string_literal: true

Mockit::Engine.routes.draw do
  post "/mocks", to: "mocks#create"
  get  "/mocks", to: "mocks#show"
end
