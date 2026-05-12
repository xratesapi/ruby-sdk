# frozen_string_literal: true

module XRatesApi
  # Base error raised by the SDK. Network failures, unexpected response
  # bodies and unrecognised HTTP statuses all surface as plain ApiError;
  # the four subclasses below cover the cases callers usually want to
  # branch on.
  class ApiError < StandardError
    attr_reader :status

    def initialize(message, status = 0)
      super(message)
      @status = status
    end
  end

  # HTTP 401 / 403.
  class AuthenticationError < ApiError; end

  # HTTP 429.
  class RateLimitError < ApiError; end

  # HTTP 422 — the raw response body is exposed via #payload.
  class ValidationError < ApiError
    attr_reader :payload

    def initialize(message, status, payload = {})
      super(message, status)
      @payload = payload || {}
    end
  end
end
