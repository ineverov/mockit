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
end
