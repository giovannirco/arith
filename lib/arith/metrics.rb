require "prometheus/client"
require "prometheus/client/formats/text"

module Arith
  # Prometheus metrics, served at /metrics in the text exposition format.
  #
  # Labels are kept to bounded sets: the route template rather than the path,
  # and an outcome name rather than the error text.
  class Metrics
    CONTENT_TYPE = Prometheus::Client::Formats::Text::CONTENT_TYPE

    # How a call to /api/<op> ended.
    OUTCOMES = %w[ok bad_input division_by_zero overflow].freeze

    # Half a millisecond to a few seconds. Arithmetic is fast; anything in the
    # upper buckets is the network or the scheduler.
    BUCKETS = [ 0.0005, 0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5 ].freeze

    def initialize(version: Arith::VERSION)
      @registry = Prometheus::Client::Registry.new
      @requests = @registry.counter(
        :http_requests_total,
        docstring: "HTTP requests served, by method, route template and status code",
        labels: %i[method route status]
      )
      @duration = @registry.histogram(
        :http_request_duration_seconds,
        docstring: "Time to serve an HTTP request",
        labels: %i[method route],
        buckets: BUCKETS
      )
      @operations = @registry.counter(
        :arith_operations_total,
        docstring: "Arithmetic requests, by operation and outcome",
        labels: %i[operation outcome]
      )
      @registry.gauge(:arith_build_info, docstring: "Version of the running program", labels: %i[version])
               .set(1, labels: { version: version })
    end

    def observe_request(method:, route:, status:, seconds:)
      @requests.increment(labels: { method: method, route: route, status: status.to_s })
      @duration.observe(seconds, labels: { method: method, route: route })
    end

    def observe_operation(operation, outcome)
      raise ArgumentError, "unknown outcome #{outcome.inspect}" unless OUTCOMES.include?(outcome.to_s)

      @operations.increment(labels: { operation: operation.to_s, outcome: outcome.to_s })
    end

    # The whole registry in the Prometheus text format.
    def render
      Prometheus::Client::Formats::Text.marshal(@registry)
    end
  end
end
