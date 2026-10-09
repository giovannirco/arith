require "test_helper"

class TelemetryTest < ActiveSupport::TestCase
  def build(vars) = Arith::Telemetry.build(Arith::Config.from_env(vars))

  def processors(provider) = provider.instance_variable_get(:@span_processors)
  def log_processors(provider) = provider.instance_variable_get(:@log_record_processors)

  test "console only exports nothing" do
    t = build({})
    assert_not t.exports_traces?
    assert_not t.exports_logs?
    assert_nil t.otlp_logger
  end

  test "traces over OTLP get a batch processor and the OTLP exporter" do
    t = build("OTEL_TRACES_EXPORTER" => "otlp", "OTEL_SERVICE_NAME" => "calc")
    assert t.exports_traces?
    assert_not t.exports_logs?
    processor = processors(t.tracer_provider).sole
    assert_kind_of OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor, processor
    assert_kind_of OpenTelemetry::Exporter::OTLP::Exporter, processor.instance_variable_get(:@exporter)
    attributes = t.tracer_provider.resource.attribute_enumerator.to_h
    assert_equal "calc", attributes["service.name"]
    assert_equal Arith::VERSION, attributes["service.version"]
  ensure
    t&.shutdown
  end

  test "logs over OTLP get a batch processor and the OTLP logs exporter" do
    t = build("OTEL_LOGS_EXPORTER" => "console,otlp")
    assert t.exports_logs?
    assert_not t.exports_traces?
    processor = log_processors(t.logger_provider).sole
    assert_kind_of OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor, processor
    assert_kind_of OpenTelemetry::Exporter::OTLP::Logs::LogsExporter, processor.instance_variable_get(:@exporter)
    assert_not_nil t.otlp_logger
  ensure
    t&.shutdown
  end

  test "install sets W3C trace context as the propagator" do
    build({}).install
    carrier = {}
    span = OpenTelemetry::Trace.non_recording_span(
      OpenTelemetry::Trace::SpanContext.new(trace_id: "\x0a" * 16, span_id: "\x0b" * 8,
                                            trace_flags: OpenTelemetry::Trace::TraceFlags::SAMPLED)
    )
    OpenTelemetry.propagation.inject(carrier, context: OpenTelemetry::Trace.context_with_span(span))
    assert_equal "00-#{'0a' * 16}-#{'0b' * 8}-01", carrier["traceparent"]
  end
end
