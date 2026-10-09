Rails.application.configure do
  config.enable_reloading = false
  config.eager_load = true
  config.consider_all_requests_local = false

  # The Service is plain HTTP inside the cluster; TLS, if any, ends at the
  # gateway in front. Redirecting to https would break every in-cluster call.
  config.assume_ssl = false
  config.force_ssl = false

  # Any Host header is fine: the Service name, its FQDN, a gateway hostname.
  config.hosts.clear

  config.active_support.report_deprecations = false
end
