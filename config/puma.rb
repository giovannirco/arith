# Puma serves the app: one process, a few threads, port 8000.
#
# On SIGTERM it stops accepting, lets in-flight requests finish for up to
# ARITH_SHUTDOWN_TIMEOUT seconds, then exits. Kubernetes waits
# terminationGracePeriodSeconds; keep the timeout below that.
require_relative "../lib/arith/config"
require_relative "../lib/arith/log"

begin
  arith = Arith::Config.from_env
rescue Arith::Config::Error => e
  abort "arith: #{e.message}"
end

environment ENV.fetch("RAILS_ENV", "development")
bind "tcp://#{arith.addr}"

# One process: the metrics registry lives in memory and /metrics reads it.
workers 0
threads 1, 5

force_shutdown_after arith.shutdown_timeout
raise_exception_on_sigterm false

# Puma's own startup and shutdown lines, in the service's log format.
puma_log = Arith::Log.new(format: arith.log_format)
log_formatter { |message| puma_log.format("info", message.to_s.strip, logger: "puma") }
