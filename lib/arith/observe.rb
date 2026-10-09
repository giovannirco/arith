module Arith
  # One middleware for the three signals: a span per request, the request
  # counters and histogram, and one access-log line.
  #
  # The span joins an incoming W3C traceparent when there is one, so a trace
  # started by a gateway in front of the service continues into it.
  class Observe
    # Probes and scrapes arrive every few seconds; they are logged at debug so
    # the default level shows the requests people made.
    QUIET_ROUTES = %w[/healthz /metrics].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      method = env["REQUEST_METHOD"]
      path = env["PATH_INFO"]
      query = env["QUERY_STRING"].to_s

      parent = OpenTelemetry.propagation.extract(env, getter: OpenTelemetry::Common::Propagation.rack_env_getter)
      span = Arith.telemetry.tracer.start_span(
        "#{method} unmatched",
        with_parent: parent,
        kind: :server,
        attributes: { "http.request.method" => method, "url.path" => path }
      )
      status, headers, body = OpenTelemetry::Trace.with_span(span) { @app.call(env) }

      route = route_of(env)
      span.name = "#{method} #{route}"
      span.set_attribute("http.route", route)
      span.set_attribute("http.response.status_code", status)
      span.status = OpenTelemetry::Trace::Status.error if status >= 500
      span.finish

      seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      Arith.metrics.observe_request(method: method, route: route, status: status, seconds: seconds)
      trace_id = span.context.hex_trace_id if span.context.valid?
      Arith.log.emit(
        QUIET_ROUTES.include?(route) ? "debug" : "info",
        "request",
        { method: method, path: path, query: query, route: route, status: status,
          duration_ms: (seconds * 1000).round(3), error: env["arith.error"], trace_id: trace_id },
        logger: "access",
        context: OpenTelemetry::Trace.context_with_span(span)
      )
      [ status, headers, body ]
    end

    private

    # The route template (/api/sum), not the path, keeps label cardinality
    # fixed. Requests that match no route share one label.
    def route_of(env)
      pattern = ActionDispatch::Request.new(env).route_uri_pattern
      pattern.nil? || pattern.start_with?("/*") ? "unmatched" : pattern
    end
  end
end
