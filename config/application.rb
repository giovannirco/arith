require_relative "boot"

require "rails"
# Only the frameworks this service uses: no database, mail, jobs or views.
require "action_controller/railtie"
require "rails/test_unit/railtie"

Bundler.require(*Rails.groups)

require_relative "../lib/arith"

module Arith
  class Application < Rails::Application
    config.load_defaults 8.1
    config.api_only = true

    # Rails wants a secret_key_base in production even though this service
    # signs and encrypts nothing: no cookies, no sessions, no credentials. A
    # random one per process is enough; SECRET_KEY_BASE overrides it.
    config.secret_key_base = ENV.fetch("SECRET_KEY_BASE") { SecureRandom.hex(64) }

    # lib/ is plain Ruby, required above; only app/ is autoloaded.
    config.autoload_paths = []
    config.eager_load_paths = []

    # Nothing is served from public/; the page lives in web/ and is routed.
    config.public_file_server.enabled = false

    # Settings and the log are needed before Rails picks a logger, or it opens
    # log/production.log. Rails keeps warnings and errors, in the same format;
    # one access-log line per request comes from Arith::Observe instead of
    # Rails' own request lines.
    Arith.config = Arith::Config.from_env
    Arith.log = Arith::Log.new(level: Arith.config.log_level, format: Arith.config.log_format,
                               console: Arith.config.logs_console)
    config.logger = Arith.log.logger_for("rails")
    config.log_level = :warn
    config.middleware.delete Rails::Rack::Logger
    config.middleware.insert_before 0, Arith::Observe

    # An exception that escapes a controller still answers in JSON.
    config.exceptions_app = lambda do |env|
      status = env["PATH_INFO"].delete_prefix("/").to_i
      status = 500 unless status.between?(400, 599)
      message = Rack::Utils::HTTP_STATUS_CODES.fetch(status, "error").downcase
      [ status, { "content-type" => "application/json" }, [ JSON.generate(error: message) ] ]
    end
  end
end
