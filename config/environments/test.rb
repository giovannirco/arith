Rails.application.configure do
  config.enable_reloading = false
  # Load everything once, so a file that does not load fails the suite.
  config.eager_load = true
  config.consider_all_requests_local = false
  # Exceptions reach the JSON exceptions_app, as they do in production.
  config.action_dispatch.show_exceptions = :all

  config.active_support.deprecation = :stderr
  config.action_controller.raise_on_missing_callback_actions = true
end
