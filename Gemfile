source "https://rubygems.org"

# Any Ruby 4.0; .ruby-version names the one CI and the image use.
ruby "~> 4.0"

# Rails without the parts this service has no use for: no database, no mail,
# no jobs, no views. Railties boots the app; Action Pack routes and renders.
gem "actionpack", "~> 8.1.4"
gem "railties", "~> 8.1.4"

gem "puma", "~> 8.0"

# Time zone data as a gem, so the image needs no zoneinfo files.
gem "tzinfo-data", "~> 1.2026"

gem "prometheus-client", "~> 5.0"

# Traces and logs over OTLP (http/protobuf), off unless OTEL_* asks for them.
gem "opentelemetry-exporter-otlp", "~> 0.37"
gem "opentelemetry-exporter-otlp-logs", "~> 0.6"
gem "opentelemetry-logs-sdk", "~> 0.8"
gem "opentelemetry-sdk", "~> 1.13"

group :development, :test do
  gem "rubocop-rails-omakase", "~> 1.1", require: false
end

group :test do
  gem "simplecov", "~> 1.3", require: false
end
