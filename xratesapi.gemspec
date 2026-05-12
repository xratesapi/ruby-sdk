Gem::Specification.new do |spec|
  spec.name          = "xratesapi"
  spec.version       = "0.1.0"
  spec.authors       = ["XRates Team"]
  spec.email         = ["support@xratesapi.com"]
  spec.summary       = "Official Ruby SDK for the XRates exchange rate API."
  spec.description   = "Thin client for xratesapi.com — multi-source FX rates over a single REST endpoint, with typed errors and zero third-party dependencies."
  spec.homepage      = "https://xratesapi.com"
  spec.license       = "MIT"

  spec.required_ruby_version = ">= 2.7"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.metadata = {
    "homepage_uri"      => "https://xratesapi.com",
    "source_code_uri"   => "https://github.com/xratesapi/ruby-sdk",
    "bug_tracker_uri"   => "https://github.com/xratesapi/ruby-sdk/issues",
    "documentation_uri" => "https://xratesapi.com/docs",
  }

  spec.add_development_dependency "minitest", "~> 5.18"
  spec.add_development_dependency "rake", "~> 13.0"
end
