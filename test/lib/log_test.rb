require "test_helper"

class LogTest < ActiveSupport::TestCase
  def lines(out) = out.string.lines.map(&:chomp)

  test "one JSON object per line" do
    out = StringIO.new
    Arith::Log.new(out: out).info("request", status: 200, error: nil, path: "/api/sum")
    record = JSON.parse(lines(out).sole)
    assert_equal "info", record["level"]
    assert_equal "request", record["message"]
    assert_equal 200, record["status"]
    assert_equal "/api/sum", record["path"]
    assert_equal "arith", record["logger"]
    assert_not record.key?("error"), "nil fields are left out"
    assert_match(/\A\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d\.\d{3}Z\z/, record["time"])
  end

  test "text for people" do
    out = StringIO.new
    Arith::Log.new(format: "text", out: out).emit("info", "request", { query: "", status: 200 }, logger: "access")
    assert_match(/\A\S+  INFO access: request query="" status=200\z/, lines(out).sole)
  end

  test "lines below the level are dropped" do
    out = StringIO.new
    log = Arith::Log.new(level: "warn", out: out)
    log.debug("quiet")
    log.info("quiet")
    log.warn("loud")
    log.error("louder")
    assert_equal %w[loud louder], lines(out).map { |line| JSON.parse(line)["message"] }
  end

  test "console off writes nothing" do
    out = StringIO.new
    Arith::Log.new(console: false, out: out).info("request")
    assert_empty out.string
  end

  test "a Logger for Rails writes the same format" do
    out = StringIO.new
    logger = Arith::Log.new(out: out).logger_for("rails")
    logger.info("dropped below warn")
    logger.error("boom")
    record = JSON.parse(lines(out).sole)
    assert_equal [ "error", "boom", "rails" ], record.values_at("level", "message", "logger")
  end

  test "records over OTLP carry the span's trace id" do
    exporter = OpenTelemetry::SDK::Logs::Export::InMemoryLogRecordExporter.new
    telemetry = Arith::Telemetry.build(Arith::Config.from_env({}), log_exporter: exporter)
    log = Arith::Log.new(console: false, otlp_logger: telemetry.otlp_logger)
    span = OpenTelemetry::Trace.non_recording_span(
      OpenTelemetry::Trace::SpanContext.new(trace_id: "\x01" * 16, span_id: "\x02" * 8)
    )
    log.emit("warn", "request", { status: 400 }, logger: "access", context: OpenTelemetry::Trace.context_with_span(span))

    record = exporter.emitted_log_records.sole
    assert_equal "request", record.body
    assert_equal "WARN", record.severity_text
    assert_equal 13, record.severity_number
    assert_equal({ "status" => 400, "logger" => "access" }, record.attributes)
    assert_equal "\x01" * 16, record.trace_id
  end
end
