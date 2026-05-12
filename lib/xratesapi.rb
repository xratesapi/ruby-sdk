# frozen_string_literal: true

require_relative "xratesapi/version"
require_relative "xratesapi/errors"
require_relative "xratesapi/client"

# Official Ruby SDK for the XRates exchange rate API.
#
# Quick start:
#   require "xratesapi"
#   client = XRatesApi::Client.new(ENV["XRATES_API_KEY"])
#   client.latest(base: "USD", symbols: %w[EUR GBP])
module XRatesApi
end
