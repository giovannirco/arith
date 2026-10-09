require "test_helper"

# What one request leaves behind: counters, an access-log line, a span.
class ObserveTest < ActionDispatch::IntegrationTest
  TRACEPARENT = "00-0af7651916cd43dd8448eb211c80319c-b7ad6b7169203331-01".freeze

  setup do
    @out = StringIO.new
    @log = Arith.log
    Arith.log = Arith::Log.new(level: "info", out: @out)
  end

  teardown { Arith.log = @log }

  def access_lines = @out.string.lines.map { |line| JSON.parse(line) }.select { |r| r["logger"] == "access" }

  test "metrics count what was served" do
    %w[
      /api/sum?term_one=4&term_two=1
      /api/sum?term_one=4&term_two=1
      /api/div?term_one=1&term_two=0
      /api/mul?term_one=x&term_two=1
      /nope
    ].each { |uri| get uri }

    get "/metrics"
    assert_response 200
    assert_match %r{\Atext/plain; version=0\.0\.4}, response.content_type
    [
      'http_requests_total{method="GET",route="/api/sum",status="200"} 2.0',
      'http_requests_total{method="GET",route="/api/div",status="400"} 1.0',
      'http_requests_total{method="GET",route="unmatched",status="404"} 1.0',
      'http_request_duration_seconds_count{method="GET",route="/api/sum"} 2.0',
      'arith_operations_total{operation="sum",outcome="ok"} 2.0',
      'arith_operations_total{operation="div",outcome="division_by_zero"} 1.0',
      'arith_operations_total{operation="mul",outcome="bad_input"} 1.0',
      "arith_build_info{version="
    ].each { |line| assert_includes response.body, line }
  end

  test "one access line per request, with the error text and the route" do
    get "/api/div?term_one=1&term_two=0"
    line = access_lines.sole
    assert_equal "info", line["level"]
    assert_equal [ "GET", "/api/div", "term_one=1&term_two=0", "/api/div", 400, "division by zero" ],
                 line.values_at("method", "path", "query", "route", "status", "error")
    assert_kind_of Numeric, line["duration_ms"]
  end

  test "probes and scrapes are logged at debug" do
    get "/healthz"
    get "/metrics"
    assert_empty access_lines
  end

  test "a caller's traceparent puts its trace id on the line" do
    get "/api/sum?term_one=4&term_two=1", headers: { "traceparent" => TRACEPARENT }
    assert_equal "0af7651916cd43dd8448eb211c80319c", access_lines.sole["trace_id"]
  end

  test "one span per request, joined to the caller's trace" do
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    telemetry = Arith.telemetry
    Arith.telemetry = Arith::Telemetry.build(Arith.config, span_exporter: exporter)

    get "/api/sum?term_one=4&term_two=1", headers: { "traceparent" => TRACEPARENT }
    get "/api/div?term_one=1&term_two=0"
    get "/nope"

    spans = exporter.finished_spans
    assert_equal [ "GET /api/sum", "GET /api/div", "GET unmatched" ], spans.map(&:name)

    sum = spans.first
    assert_equal "0af7651916cd43dd8448eb211c80319c", sum.hex_trace_id, "continues the caller's trace"
    assert_equal "b7ad6b7169203331", sum.hex_parent_span_id
    assert_equal :server, sum.kind
    assert_equal "/api/sum", sum.attributes["http.route"]
    assert_equal "GET", sum.attributes["http.request.method"]
    assert_equal "/api/sum", sum.attributes["url.path"]
    assert_equal 200, sum.attributes["http.response.status_code"]

    div = spans.second
    assert_not_equal sum.hex_trace_id, div.hex_trace_id, "starts its own trace"
    assert_equal 400, div.attributes["http.response.status_code"]
  ensure
    Arith.telemetry = telemetry
  end

  test "a 5xx marks the span as an error" do
    exporter = OpenTelemetry::SDK::Trace::Export::InMemorySpanExporter.new
    telemetry = Arith.telemetry
    Arith.telemetry = Arith::Telemetry.build(Arith.config, span_exporter: exporter)
    MetricsController.class_eval { alias_method :original_show, :show }
    MetricsController.define_method(:show) { raise "boom" }

    get "/metrics"
    assert_response 500
    assert_equal OpenTelemetry::Trace::Status::ERROR, exporter.finished_spans.sole.status.code
  ensure
    Arith.telemetry = telemetry
    MetricsController.class_eval do
      alias_method :show, :original_show
      remove_method :original_show
    end
  end
end
