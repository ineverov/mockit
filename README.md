# Mockit

> 🔧 Smart service mocking for Rails apps during end-to-end testing — scoped, isolated, and built for multi-repo setups.

**Mockit** allows you to inject mock responses for external services during end-to-end (E2E) or integration testing. It works seamlessly even when your test suite is outside your main Rails app (e.g., Cypress, mobile tests, etc.).


---


## ✨ Features

* 🎯 Targeted mocking using `X-Mockit-Id` header
* ⚙️ Middleware-based context tracking (HTTP + Sidekiq)
* 🧪 Dynamic mock injection via REST API
* 🔄 Works across web requests and background jobs
* 🧩 Plug-and-play method overrides via modules
* ♻️ Cache-backed mock store with TTL

---

## 🛠 Installation

Add to your Gemfile:

```ruby
gem 'mockit', git: 'https://ineverov/mockit.git'
```

Bundle it:

```bash
bundle install
```

Mount the engine in your app:

```ruby
# config/routes.rb
mount Mockit::Engine => "/mockit"
```

This also mounts a browsable scenario-picker UI at `/mockit/ui` alongside the JSON API — see [Scenario-picker UI](#-scenario-picker-ui) below, including a note on restricting access to it.

---

## ⚙️ Configuration

Mockit injects middleware for both HTTP and Sidekiq automatically.

If using Sidekiq, make sure it’s required early:

```ruby
# config/application.rb
require 'mockit'
```

---

## 🚀 Usage

### 1. Inject a Mock

Send a mock payload to the Mockit API:

```bash
curl -X POST http://localhost:3000/mockit/mocks \
  -H "Content-Type: application/json" \
  -d '{
    "service": "external_service",
    "overrides": {
      "key": "mocked_value"
    }
  }'
```

### 2. Trigger Test Request With `X-Mockit-Id`

```bash
curl -H "X-Mockit-Id: 123" http://localhost:3000/my_feature
```

The app will now receive mocked responses for `external_service#get_data`.

---

## 🧬 Define a Mock Module

Create a module under `Mockit::Mock::<YourClientClassName>` with `mock_` prefixed methods:

```ruby
# app/lib/mockit/mock/external_client.rb
module Mockit::Mock::ExternalClient
  def mock_get_data(override_response, real_method, *args)
    OpenStruct.new(override_response)
  end
end
```

---

## 🔗 Enable Mocking in Your Code

Call `Mockit.mock_classes` in an initializer or during boot:

```ruby
# config/initializers/mockit.rb
Mockit.mock_classes(External::Client => MockModuleForClient)
```

This will dynamically override methods if mocks are present.

---

## 🧠 Example Flow (End-to-End)

1. Your external test runner (e.g., Cypress) creates a mock:

   ```bash
   curl -X POST http://localhost:3000/mockit/mocks \
     -H "Content-Type: application/json" \
     -H "X-Mockit-Id: test-abc-1" \
     -d '{
       "service": "external_service",
       "overrides": {
         "status": "ok",
         "data": "mocked"
       }
     }'
   ```

2. It then starts the real app flow using the same mock ID:

   ```bash
   curl -H "X-Mockit-Id: test-abc-1" http://localhost:3000/start_flow
   ```

3. Your app internally calls `ExternalClient#fetch_info`, which is overridden to return the mock.

---

## 🧪 Testing Background Jobs

Mockit supports Sidekiq seamlessly:

* Client middleware copies `mockit_id` to the job
* Server middleware restores it during job execution

This means your mocked context survives across async workflows.

---

## 🗃 Mock Storage

Mockit stores mocks in `Rails.cache` using a scoped key:

```
mockit:<mock_id>:<service>
```

Mocks expire after 10 minutes by default (`ttl: 600s`), configurable per call.

---

## 📬 API

### POST `/mockit/mocks`

Set a mock response.

#### Params

* `service`: String (required)
* `overrides`: JSON (required)

```json
{
  "service": "external_service",
  "overrides": { "result": "ok" }
}
```

---

### GET `/mockit/mocks`

Retrieve a mock response.

#### Query Params

* `service`: String (required)

---

## 🖥 Scenario-picker UI

A server-rendered UI is mounted at `/mockit/ui` alongside the JSON API, backed by the same `Mockit::Store` (`/mockit/mocks` and `/mockit/map_request` are untouched). No JavaScript, no extra gem dependencies.

Unlike the JSON API, the UI renders HTML forms and needs session middleware enabled in the host app (for CSRF protection and flash messages) — the same requirement `Sidekiq::Web` and `Flipper::UI` have. Most Rails apps have this by default; a host running `config.api_only = true` does not, and needs to add it back (see the [Rails guide](https://guides.rubyonrails.org/api_app.html#using-session-middlewares)) before `/mockit/ui` will work. Visiting `/mockit/ui` without session middleware renders an explanatory error instead of a bare stack trace.

* `GET /mockit/ui` — enter a mock id (the same value normally sent as `X-Mockit-Id`). Pre-filled with `Mockit.default_mock_id` when a host app has set one, so you usually just hit Enter instead of typing it — but it never redirects past this prompt on its own.
* `GET /mockit/ui/:mock_id` — lists every service currently overridden for that mock id, plus every service with a registered scenario (see below) even if it isn't mocked yet for this mock id. A "Switch mock ID" field at the top lets you jump to a different id without going back to `/mockit/ui`.
* Each service row shows a scenario picker (if any are registered), a "Reset to happy path" button (if a `default: true` scenario is registered), and "Delete (use real connection)" to remove the override and let the real vendor call through. The raw JSON edit-and-apply form still exists per service, collapsed under "Advanced: edit JSON directly".
* "Delete all overrides for this mock ID" tears down every override and mapping for that mock id (same as `DELETE /mockit/mocks/teardown`).

### Named scenarios

Register reusable override sets in code — checked into your repo, similar in spirit to picking a VCR cassette — so the picker offers a dropdown instead of requiring hand-typed JSON every time:

```ruby
# config/initializers/mockit.rb
Mockit.register_scenario(
  service: "external_service",
  name: "happy_path",
  default: true, # what "Reset to happy path" re-applies
  overrides: -> { { "status" => "ok", "data" => build_happy_path_payload } } # or a plain Hash
)
```

`overrides` may be a `Hash` (used as-is) or a zero-arg callable, resolved fresh every time the scenario is applied — use a callable when the payload has to be built at apply-time (e.g. from a factory) rather than baked in once at boot. At most one scenario per service should be `default: true`.

### Access restriction

The UI implements **no authentication or authorization of its own** — same posture as `Sidekiq::Web` or `Flipper::UI`: the gem ships a mountable engine, and it's the host app's job to decide whether and how to restrict it. `Mockit::Engine`'s mount is commonly guarded only by environment (`unless Rails.env.production?`), which is *not* an access-control mechanism — it just keeps the engine out of production. If you want to restrict who can reach the UI (e.g. in a shared staging environment), wrap the mount in your own auth constraint:

```ruby
# config/routes.rb
authenticate(:user, ->(u) { u.admin? }) do
  mount Mockit::Engine, at: "/mockit"
end
```

Note that constraining the mount this way also gates the JSON API (`/mockit/mocks`, `/mockit/map_request`) behind the same check — if automated test suites call those endpoints directly (as `X-Mockit-Id`-only clients, with no session), a session-based constraint like the example above will break them. Machine callers need a different mechanism (e.g. a shared API key) than a human clicking through the UI; this gem doesn't prescribe one, since it depends on how each host app already authenticates its internal tooling.

### Default mock id for local single-developer servers

`Mockit.default_mock_id` lets every request that carries no `X-Mockit-Id`/`X-Mock-Id` header of its own fall back to a fixed mock id, instead of running unmocked. An explicit header still always wins. This is meant for a local dev server with exactly one user — not staging/sandbox, where it would silently mock every engineer's traffic:

```ruby
# config/initializers/mockit.rb, guarded to development only
Mockit.default_mock_id = "dev-default" if Rails.env.development? && ENV["MOCKIT"] == "true"
```

Combine with `Mockit::Store.write(service:, overrides:)` at boot (e.g. in `Rails.application.config.after_initialize`) to seed happy-path defaults under that same id, and then browse the app normally — no header, no `/mockit/ui` visit required first. You can still open `/mockit/ui/dev-default` any time to see or change what's mocked.

`Store.write` keys off the *current request's* mock id (thread-local, via `RequestStore`), which is unset at boot — so set `Mockit::Store.mock_id` explicitly before writing, or the override silently lands under a blank id instead of `default_mock_id`:

```ruby
# config/initializers/mockit.rb, guarded to development only
Rails.application.config.after_initialize do
  Mockit::Store.mock_id = Mockit.default_mock_id
  Mockit::Store.write(service: "external_service", overrides: { "status" => "ok" })
end
```

Setting `default_mock_id` makes `/mockit/map_request` mapping rules unreachable for header-less requests, since `MockitIdMiddleware` (which runs first) already resolves a mock id before `MappingFilter` gets a chance to match — this is intentional: a fixed default and pattern-based mapping solve the same "which mock id is this request" problem, and a default is the simpler, more predictable answer when a machine's traffic all belongs to one developer anyway. Requests carrying their own header are unaffected either way.

---

# 🧩 Faraday Middleware Support for Mockit

Mockit includes a built-in Faraday middleware that automatically forwards the current `X-Mockit-Id` to downstream services during HTTP requests. This ensures mock context is preserved across service boundaries in integration or end-to-end tests.

---

## 🔧 Usage

Add the middleware to your Faraday connection:

```ruby

require 'mockit/middleware/faraday_middleware'

connection = Faraday.new(url: "https://api.example.com") do |conn|
  conn.request :mockit_header
  conn.adapter Faraday.default_adapter
end

response = connection.get("/data")
```

## 🛡 Safe for Production?

Yes — unless you explicitly send an `X-Mockit-Id` header, Mockit is dormant. Mocks are only injected when test code demands them.

---

## 📦 Version

`v0.1.0`

---

## 🛠️ Contributing

1. Fork the repo
2. Create a feature branch
3. Submit a PR with tests

---

**Mockit — Because mocking shouldn't be a pain.**

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## API Examples

Below are concrete examples of using Mockit API

1) Create a mock and fetch it

```bash
# create a mock for service `payment_service` under X-Mockit-Id: abc123
curl -X POST http://localhost:3000/mockit/mocks \
  -H "Content-Type: application/json" \
  -H "X-Mockit-Id: abc123" \
  -d '{"service":"payment_service","overrides":{"message":"success","code":200}}'

# fetch it
curl "http://localhost:3000/mockit/mocks?service=payment_service" -H "X-Mockit-Id: abc123"
```

2) Create a mapping rule (path + ttl)

```bash
# map requests matching path ^/ttl$ to the mock id present on the current request
# (set the mock id via header `X-Mockit-Id` or legacy `X-Mock-Id`)
curl -X POST http://localhost:3000/mockit/map_request \
  -H "Content-Type: application/json" \
  -H "X-Mockit-Id: abc" \
  -d '{"match":{"path":"^/ttl$"}, "ttl":10 }'
```

3) Create mappings with header or query param matching

```bash
# match on header X-Foo == "bar" (mock id provided via request header)
curl -X POST http://localhost:3000/mockit/map_request \
  -H "Content-Type: application/json" \
  -H "X-Mockit-Id: h-mock" \
  -d '{"match":{"path":".*","headers":{"X-Foo":"^bar$"}} }'

# match on query param q=find (mock id provided via request header)
curl -X POST http://localhost:3000/mockit/map_request \
  -H "Content-Type: application/json" \
  -H "X-Mockit-Id: p-mock" \
  -d '{"match":{"path":".*","params":{"q":"^find$"}} }'
```

4) Teardown mocks for a mock id (used in tests)

```bash
# when your request carries X-Mockit-Id header, teardown deletes all mocks/mappings for that id
curl -X DELETE http://localhost:3000/mockit/mocks/teardown -H "X-Mockit-Id: m-abc"
```
