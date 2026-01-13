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
# (set the mock id via header `X-Mockit-Id` or legacy `X-Mockit-Id`)
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
