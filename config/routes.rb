# frozen_string_literal: true

Mockit::Engine.routes.draw do
  post   "/mocks", to: "mocks#create"
  get    "/mocks/:service", to: "mocks#show"
  delete "/mocks/:service", to: "mocks#destroy"
end
