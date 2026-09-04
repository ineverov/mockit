# frozen_string_literal: true

Mockit::Engine.routes.draw do
  post "/mocks", to: "mocks#create"
  get  "/mocks", to: "mocks#show"
  delete "/mocks", to: "mocks#destroy"
  delete "/mocks/teardown", to: "mocks#destroy_all"
  post "/map_request", to: "mocks#create_mapping"

  # Controller keyword is "scenarios", not "ui" -- see ScenariosController's class
  # comment for why (host-app "UI" acronym inflections break "ui" resolution).
  get "/ui", to: "scenarios#show", as: :ui_root
  get "/ui/:mock_id", to: "scenarios#show", as: :ui_mock
  post "/ui/:mock_id/services", to: "scenarios#apply_service", as: :ui_mock_services
  post "/ui/:mock_id/services/scenario", to: "scenarios#apply_scenario", as: :ui_mock_apply_scenario
  post "/ui/:mock_id/services/reset", to: "scenarios#reset_service", as: :ui_mock_reset_service
  post "/ui/:mock_id/services/delete", to: "scenarios#destroy_service", as: :ui_mock_service_delete
  post "/ui/:mock_id/teardown", to: "scenarios#destroy_all_services", as: :ui_mock_teardown
end
