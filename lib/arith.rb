# arith: integer arithmetic over HTTP.
#
# | File                  | Holds                                         |
# |-----------------------|-----------------------------------------------|
# | app/models/calc.rb    | the four operations on 64-bit integers        |
# | app/models/terms.rb   | reading term_one and term_two from a query    |
# | app/controllers/      | the JSON handlers, the page, /healthz, errors |
# | lib/arith/observe.rb  | the per-request span, metrics and access log  |
# | lib/arith/metrics.rb  | the Prometheus registry behind /metrics       |
# | lib/arith/telemetry.rb| where logs and traces are sent                |
# | lib/arith/log.rb      | the log line format                           |
# | lib/arith/config.rb   | the environment variables                     |
# | config/puma.rb        | listening and graceful shutdown               |
#
# The process-wide pieces are set up once, by config/initializers/arith.rb.
require_relative "arith/version"
require_relative "arith/config"
require_relative "arith/log"
require_relative "arith/metrics"
require_relative "arith/telemetry"
require_relative "arith/observe"

module Arith
  class << self
    attr_accessor :config, :log, :metrics, :telemetry
  end
end
