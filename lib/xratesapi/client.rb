# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module XRatesApi
  DEFAULT_BASE_URL = "https://xratesapi.com"
  DATE_RE = /\A\d{4}-\d{2}-\d{2}\z/.freeze

  # Thin HTTP client wrapping the XRates REST API. Stateless beyond the
  # API key — every method is one HTTP request, errors map cleanly to
  # one of four exception classes.
  class Client
    def initialize(api_key, base_url: DEFAULT_BASE_URL, timeout: 10, http: nil)
      raise ArgumentError, "XRates API key is required" if api_key.nil? || api_key.empty?

      @api_key  = api_key
      @base_url = base_url.chomp("/")
      @timeout  = timeout
      @http     = http # optional override; must respond to #request(req)
    end

    # Latest rates. rates[T] reads as "X T per 1 base".
    def latest(base: "USD", symbols: nil)
      get("/api/v1/latest", rate_params(base, symbols))
    end

    # Historical rates for a specific date (YYYY-MM-DD).
    def historical(date, base: "USD", symbols: nil)
      raise ArgumentError, "Date must be YYYY-MM-DD, got: #{date}" unless DATE_RE.match?(date)

      get("/api/v1/#{date}", rate_params(base, symbols))
    end

    # Convert an amount between two currencies at the latest (or
    # historical, if date is given) rate.
    def convert(from, to, amount, date: nil)
      params = { "from" => from, "to" => to, "amount" => amount }
      params["date"] = date if date
      get("/api/v1/convert", params)
    end

    # Time-series of rates between two dates.
    def timeseries(start_date, end_date, base: "USD", symbols: nil)
      params = rate_params(base, symbols)
      params["start_date"] = start_date
      params["end_date"]   = end_date
      get("/api/v1/timeseries", params)
    end

    # Rate fluctuation between two dates.
    def fluctuation(start_date, end_date, base: "USD", symbols: nil)
      params = rate_params(base, symbols)
      params["start_date"] = start_date
      params["end_date"]   = end_date
      get("/api/v1/fluctuation", params)
    end

    # List of supported currencies.
    def currencies
      get("/api/v1/currencies", {})
    end

    # Public status endpoint.
    def status
      get("/api/v1/status", {})
    end

    private

    def rate_params(base, symbols)
      params = { "base" => base }
      params["symbols"] = Array(symbols).join(",") if symbols && !Array(symbols).empty?
      params
    end

    def get(path, params)
      uri = URI(@base_url + path)
      uri.query = URI.encode_www_form(params) unless params.empty?

      req = Net::HTTP::Get.new(uri)
      req["Authorization"] = "Bearer #{@api_key}"
      req["Accept"]        = "application/json"
      req["User-Agent"]    = "xratesapi-ruby/#{VERSION}"

      response =
        if @http
          @http.request(req)
        else
          http = Net::HTTP.new(uri.hostname, uri.port)
          http.use_ssl = uri.scheme == "https"
          http.open_timeout = @timeout
          http.read_timeout = @timeout
          http.request(req)
        end

      decode(response)
    rescue StandardError => e
      raise if e.is_a?(ApiError)

      raise ApiError.new("Network error talking to XRates: #{e.message}")
    end

    def decode(response)
      status = response.code.to_i
      body   = response.body.to_s

      decoded =
        begin
          JSON.parse(body)
        rescue JSON::ParserError
          raise ApiError.new("Unexpected non-JSON response from XRates (HTTP #{status}).", status)
        end

      unless decoded.is_a?(Hash)
        raise ApiError.new("Unexpected response shape from XRates (HTTP #{status}).", status)
      end

      return decoded if status == 200

      message = decoded["message"] || decoded["error"] || "XRates API error"

      case status
      when 401, 403 then raise AuthenticationError.new(message, status)
      when 422      then raise ValidationError.new(message, status, decoded)
      when 429      then raise RateLimitError.new(message, status)
      else               raise ApiError.new(message, status)
      end
    end
  end
end
