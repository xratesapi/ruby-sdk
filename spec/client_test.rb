# frozen_string_literal: true

require "minitest/autorun"
require "json"
require_relative "../lib/xratesapi"

# Minimal fake HTTP object: responds to #request(req) the way Net::HTTP
# does, and records every request for assertions.
class FakeHTTP
  attr_reader :requests

  def initialize(responses)
    @responses = responses
    @index = 0
    @requests = []
  end

  def request(req)
    @requests << req
    spec = @responses[@index]
    @index += 1
    raise "no mock response queued" unless spec

    FakeResponse.new(spec[:status], spec[:body])
  end
end

class FakeResponse
  def initialize(code, body)
    @code = code
    @body = body
  end

  def code; @code.to_s; end
  def body; @body; end
end

def json_response(status, hash)
  { status: status, body: JSON.dump(hash) }
end

def make_client(http)
  XRatesApi::Client.new("test-key", http: http)
end

describe XRatesApi::Client do
  it "rejects an empty API key" do
    assert_raises(ArgumentError) { XRatesApi::Client.new("") }
    assert_raises(ArgumentError) { XRatesApi::Client.new(nil) }
  end

  it "sends Bearer token and parses successful latest()" do
    http = FakeHTTP.new([json_response(200, { "base" => "USD", "rates" => { "EUR" => 0.92 } })])
    client = make_client(http)

    result = client.latest(symbols: %w[EUR GBP])

    assert_equal({ "base" => "USD", "rates" => { "EUR" => 0.92 } }, result)
    req = http.requests.first
    assert_equal "Bearer test-key", req["Authorization"]
    assert_equal "application/json", req["Accept"]
    assert_includes req.uri.to_s, "/api/v1/latest"
    assert_includes req.uri.query, "base=USD"
    assert_includes req.uri.query, "symbols=EUR%2CGBP"
  end

  it "validates the historical date format" do
    client = make_client(FakeHTTP.new([]))
    assert_raises(ArgumentError) { client.historical("2024-1-1") }
  end

  it "historical() hits the dated endpoint" do
    http = FakeHTTP.new([json_response(200, { "date" => "2024-01-15" })])
    client = make_client(http)

    client.historical("2024-01-15", base: "EUR")

    req = http.requests.first
    assert_includes req.uri.to_s, "/api/v1/2024-01-15"
    assert_includes req.uri.query, "base=EUR"
  end

  it "convert() forwards from/to/amount" do
    http = FakeHTTP.new([json_response(200, { "result" => 92 })])
    client = make_client(http)

    out = client.convert("USD", "EUR", 100)

    assert_equal 92, out["result"]
    q = http.requests.first.uri.query
    assert_includes q, "from=USD"
    assert_includes q, "to=EUR"
    assert_includes q, "amount=100"
  end

  it "timeseries() includes start/end dates" do
    http = FakeHTTP.new([json_response(200, { "rates" => {} })])
    client = make_client(http)

    client.timeseries("2024-01-01", "2024-01-31", symbols: ["EUR"])

    q = http.requests.first.uri.query
    assert_includes q, "start_date=2024-01-01"
    assert_includes q, "end_date=2024-01-31"
    assert_includes q, "symbols=EUR"
  end

  it "fluctuation() hits the fluctuation endpoint" do
    http = FakeHTTP.new([json_response(200, { "rates" => {} })])
    client = make_client(http)
    client.fluctuation("2024-01-01", "2024-01-07")
    assert_includes http.requests.first.uri.to_s, "/api/v1/fluctuation"
  end

  it "currencies() and status() work without parameters" do
    http = FakeHTTP.new([
      json_response(200, { "currencies" => {} }),
      json_response(200, { "status" => "ok" })
    ])
    client = make_client(http)

    client.currencies
    client.status

    assert_includes http.requests[0].uri.to_s, "/api/v1/currencies"
    assert_includes http.requests[1].uri.to_s, "/api/v1/status"
  end

  it "maps 401 to AuthenticationError" do
    http = FakeHTTP.new([json_response(401, { "message" => "Invalid token" })])
    err = assert_raises(XRatesApi::AuthenticationError) { make_client(http).latest }
    assert_equal 401, err.status
  end

  it "maps 429 to RateLimitError" do
    http = FakeHTTP.new([json_response(429, { "message" => "slow down" })])
    assert_raises(XRatesApi::RateLimitError) { make_client(http).latest }
  end

  it "maps 422 to ValidationError with payload" do
    payload = { "message" => "invalid", "errors" => { "base" => ["unsupported"] } }
    http = FakeHTTP.new([json_response(422, payload)])

    err = assert_raises(XRatesApi::ValidationError) { make_client(http).latest(base: "XXX") }

    assert_equal 422, err.status
    assert_equal payload, err.payload
  end

  it "maps 500 to plain ApiError, not any subclass" do
    http = FakeHTTP.new([json_response(500, { "message" => "oops" })])
    err = assert_raises(XRatesApi::ApiError) { make_client(http).latest }

    refute_kind_of XRatesApi::AuthenticationError, err
    refute_kind_of XRatesApi::RateLimitError, err
    refute_kind_of XRatesApi::ValidationError, err
  end

  it "throws ApiError on non-JSON response body" do
    http = FakeHTTP.new([{ status: 200, body: "<html>nope</html>" }])
    err = assert_raises(XRatesApi::ApiError) { make_client(http).latest }
    assert_includes err.message, "non-JSON"
  end

  it "wraps low-level network errors in ApiError" do
    klass = Class.new do
      def request(_req); raise SocketError, "network down"; end
    end
    err = assert_raises(XRatesApi::ApiError) { make_client(klass.new).latest }
    assert_includes err.message, "Network error"
  end
end
