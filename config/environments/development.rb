Rails.application.configure do
  config.enable_reloading = true
  config.eager_load = false
  config.consider_all_requests_local = true
  config.server_timing = true

  config.active_support.deprecation = :log

  # make run serves on 0.0.0.0:8000; any Host header reaches it.
  config.hosts.clear
end
