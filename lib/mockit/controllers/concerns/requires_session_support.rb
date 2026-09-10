# frozen_string_literal: true

module Mockit
  # Guards a controller that renders HTML forms (CSRF + flash) against hosts
  # with no session middleware -- e.g. `config.api_only = true`, which never
  # inserts ActionDispatch::Flash, so an unguarded `flash` call fails with a
  # bare NoMethodError rather than anything session-specific. Same
  # requirement Sidekiq::Web and Flipper::UI have; see README
  # "Scenario-picker UI" for the reasoning.
  module RequiresSessionSupport
    extend ActiveSupport::Concern

    MISSING_SESSION_MESSAGE = <<~TEXT
      Mockit's scenario-picker UI needs session middleware enabled in this host app.

      Unlike Mockit's JSON API (/mocks, /map_request), the UI renders forms and
      relies on CSRF + flash, which are backed by Rack session support. This host
      app appears to have session middleware disabled -- most commonly because of
      `config.api_only = true`.

      Add session support before mounting Mockit::Engine, e.g.:

        config.middleware.use ActionDispatch::Cookies
        config.middleware.use ActionDispatch::Session::CookieStore

      See https://guides.rubyonrails.org/api_app.html#using-session-middlewares
    TEXT

    included do
      prepend_before_action :ensure_session_support!
    end

    private

    def ensure_session_support!
      render_missing_session unless request.respond_to?(:flash) && request.session.enabled?
    end

    def render_missing_session
      render plain: MISSING_SESSION_MESSAGE, status: :internal_server_error
    end
  end
end
