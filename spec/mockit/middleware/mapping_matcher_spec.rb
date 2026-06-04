# frozen_string_literal: true

require "spec_helper"

RSpec.describe Mockit::Middleware::MappingMatcher do
  it "matches path regex" do
    mapping = { "match" => { "path" => "^/loan/.*/details$" } }
    env = { "PATH_INFO" => "/loan/123/details" }
    expect(described_class.match?(mapping, env)).to be true
  end

  it "returns false for invalid regex" do
    mapping = { "match" => { "path" => "[" } }
    env = { "PATH_INFO" => "/anything" }
    expect(described_class.match?(mapping, env)).to be false
  end

  it "returns false for invalid header regex" do
    mapping = { "match" => { "headers" => { "X-Foo" => "[" } } }
    env = { "PATH_INFO" => "/anything", "HTTP_X_FOO" => "bar" }
    expect(described_class.match?(mapping, env)).to be false
  end

  it "returns false for invalid params regex" do
    mapping = { "match" => { "params" => { "q" => "[" } } }
    env = { "PATH_INFO" => "/anything", "QUERY_STRING" => "q=find" }
    expect(described_class.match?(mapping, env)).to be false
  end

  it "matches on remote_address when provided" do
    mapping = { "match" => { "path" => ".*", "remote_address" => "9.9.9.9" } }
    env = { "PATH_INFO" => "/anything", "REMOTE_ADDR" => "9.9.9.9" }
    expect(described_class.match?(mapping, env)).to be true
  end

  it "matches on header values when provided" do
    mapping = { "match" => { "path" => ".*", "headers" => { "X-Foo" => "^bar$" } } }
    env = { "PATH_INFO" => "/anything", "HTTP_X_FOO" => "bar" }
    expect(described_class.match?(mapping, env)).to be true
  end

  it "matches on query params when provided" do
    mapping = { "match" => { "path" => ".*", "params" => { "q" => "^find$" } } }
    env = { "PATH_INFO" => "/anything", "QUERY_STRING" => "q=find" }
    expect(described_class.match?(mapping, env)).to be true
  end

  it "matches header literal equality when non-string value provided" do
    mapping = { "match" => { "headers" => { "X-Foo" => 123 } } }
    env = { "PATH_INFO" => "/anything", "HTTP_X_FOO" => 123 }
    expect(described_class.match?(mapping, env)).to be true
  end

  it "matches param literal equality when non-string value provided" do
    mapping = { "match" => { "params" => { "page" => 2 } } }
    env = { "PATH_INFO" => "/anything", "QUERY_STRING" => "page=2" }
    expect(described_class.match?(mapping, env)).to be true
  end

  def env_with_body(body, extra = {})
    { "PATH_INFO" => "/anything", "rack.input" => StringIO.new(body) }.merge(extra)
  end

  describe "body matching" do
    it "matches raw body with regex" do
      mapping = { "match" => { "body" => "hello" } }
      expect(described_class.match?(mapping, env_with_body("say hello world"))).to be true
    end

    it "returns false when raw body does not match regex" do
      mapping = { "match" => { "body" => "^hello$" } }
      expect(described_class.match?(mapping, env_with_body("say hello world"))).to be false
    end

    it "rewinds rack.input so body is readable after matching" do
      mapping = { "match" => { "body" => "hello" } }
      input = StringIO.new("hello")
      env = { "PATH_INFO" => "/anything", "rack.input" => input }
      described_class.match?(mapping, env)
      expect(input.read).to eq("hello")
    end

    it "returns true when no body key in match" do
      mapping = { "match" => {} }
      expect(described_class.match?(mapping, env_with_body("anything"))).to be true
    end
  end

  describe "body_json matching" do
    it "matches flat JSON key with regex" do
      mapping = { "match" => { "body_json" => { "action" => "^create$" } } }
      expect(described_class.match?(mapping, env_with_body('{"action":"create"}'))).to be true
    end

    it "returns false when flat JSON key does not match" do
      mapping = { "match" => { "body_json" => { "action" => "^delete$" } } }
      expect(described_class.match?(mapping, env_with_body('{"action":"create"}'))).to be false
    end

    it "matches nested JSON hash" do
      mapping = { "match" => { "body_json" => { "user" => { "address" => { "city" => "New York" } } } } }
      body = '{"user":{"address":{"city":"New York"},"name":"John"}}'
      expect(described_class.match?(mapping, env_with_body(body))).to be true
    end

    it "returns false when nested value does not match" do
      mapping = { "match" => { "body_json" => { "user" => { "address" => { "city" => "Boston" } } } } }
      body = '{"user":{"address":{"city":"New York"}}}'
      expect(described_class.match?(mapping, env_with_body(body))).to be false
    end

    it "ignores extra keys in body not specified in pattern" do
      mapping = { "match" => { "body_json" => { "action" => "create" } } }
      body = '{"action":"create","unrelated":"stuff"}'
      expect(described_class.match?(mapping, env_with_body(body))).to be true
    end

    it "matches array values positionally" do
      mapping = { "match" => { "body_json" => { "ids" => %w[1 2] } } }
      body = '{"ids":["1","2","3"]}'
      expect(described_class.match?(mapping, env_with_body(body))).to be true
    end

    it "returns false when positional array element does not match" do
      mapping = { "match" => { "body_json" => { "ids" => %w[1 9] } } }
      body = '{"ids":["1","2","3"]}'
      expect(described_class.match?(mapping, env_with_body(body))).to be false
    end

    it "returns false on invalid JSON" do
      mapping = { "match" => { "body_json" => { "action" => "create" } } }
      expect(described_class.match?(mapping, env_with_body("not json"))).to be false
    end

    it "returns true when no body_json key in match" do
      mapping = { "match" => {} }
      expect(described_class.match?(mapping, env_with_body('{"action":"create"}'))).to be true
    end
  end
end
