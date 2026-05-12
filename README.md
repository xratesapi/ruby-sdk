# xratesapi

[![Release](https://img.shields.io/github/v/release/xratesapi/ruby-sdk.svg)](https://github.com/xratesapi/ruby-sdk/releases)
[![license](https://img.shields.io/github/license/xratesapi/ruby-sdk.svg)](https://github.com/xratesapi/ruby-sdk/blob/main/LICENSE)

Official Ruby SDK for the [XRates exchange rate API](https://xratesapi.com).

Ruby 2.7+ (3.x recommended), **zero third-party dependencies** (stdlib `net/http` only).

## Install

The gem is not yet published to RubyGems (registration is temporarily closed at the time of writing). Install directly from GitHub instead:

```ruby
# Gemfile
gem "xratesapi", git: "https://github.com/xratesapi/ruby-sdk", tag: "v0.1.0"
```

```bash
bundle install
```

Once RubyGems is back, this becomes:

```ruby
gem "xratesapi"
```

## Quick start

```ruby
require "xratesapi"

client = XRatesApi::Client.new(ENV["XRATES_API_KEY"])

rates     = client.latest(base: "USD", symbols: %w[EUR GBP])
converted = client.convert("USD", "EUR", 100)
```

## Methods

| Method | Endpoint |
| --- | --- |
| `latest(base: "USD", symbols: nil)` | `GET /api/v1/latest` |
| `historical(date, base: "USD", symbols: nil)` | `GET /api/v1/{YYYY-MM-DD}` |
| `convert(from, to, amount, date: nil)` | `GET /api/v1/convert` |
| `timeseries(start_date, end_date, base: "USD", symbols: nil)` | `GET /api/v1/timeseries` |
| `fluctuation(start_date, end_date, base: "USD", symbols: nil)` | `GET /api/v1/fluctuation` |
| `currencies` | `GET /api/v1/currencies` |
| `status` | `GET /api/v1/status` |

## Error handling

All errors inherit from `XRatesApi::ApiError`:

```ruby
begin
  client.latest(base: "XXX")
rescue XRatesApi::ValidationError => e
  p e.payload          # raw response body
rescue XRatesApi::RateLimitError
  # back off and retry
rescue XRatesApi::AuthenticationError
  # refresh credentials
rescue XRatesApi::ApiError => e
  warn "[#{e.status}] #{e.message}"
end
```

## Configuration

```ruby
XRatesApi::Client.new(
  api_key,
  base_url: "https://xratesapi.com",  # override for staging / self-hosted
  timeout:  30                         # seconds, applies to open + read
)
```

For complete control over the transport (retries, proxies, instrumentation),
pass any object that responds to `#request(req)` as `http:`:

```ruby
XRatesApi::Client.new(api_key, http: my_custom_http)
```

## License

MIT
