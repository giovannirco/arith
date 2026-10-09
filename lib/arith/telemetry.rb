require "opentelemetry/sdk"
require "opentelemetry/exporter/otlp"
require "opentelemetry-logs-sdk"
require "opentelemetry/exporter/otlp_logs"

module Arith
  # Where traces and logs go. Off unless the OTEL_* variables ask for OTLP:
  #
  # | OTEL_TRACES_EXPORTER=otlp      | one span per request over OTLP            |
  # | OTEL_LOGS_EXPORTER=otlp        | log records over OTLP, trace ids attached |
  # | OTEL_LOGS_EXPORTER=console     | lines on stdout (default)                 |
  # | OTEL_EXPORTER_OTLP_ENDPOINT    | the collector, Tempo or Loki              |
  #
  # The exporters read the rest of the OTEL_EXPORTER_OTLP_* family (per-signal
  # endpoints, headers, timeout) themselves.
  #
  # The providers are built here rather than through OpenTelemetry::SDK.configure,
  # which would turn trace export on when OTEL_TRACES_EXPORTER is unset.
  class Telemetry
    attr_reader :tracer_provider, :logger_provider

    def self.build(config, span_exporter: nil, log_exporter: nil)
      resource = OpenTelemetry::SDK::Resources::Resource.default.merge(
        OpenTelemetry::SDK::Resources::Resource.create(
          "service.name" => config.service_name,
          "service.version" => Arith::VERSION
        )
      )
      tracer_provider = if config.traces_otlp || span_exporter
        OpenTelemetry::SDK::Trace::TracerProvider.new(resource: resource).tap do |provider|
          provider.add_span_processor(processor_for(span_exporter) ||
            OpenTelemetry::SDK::Trace::Export::BatchSpanProcessor.new(OpenTelemetry::Exporter::OTLP::Exporter.new))
        end
      end
      logger_provider = if config.logs_otlp || log_exporter
        OpenTelemetry::SDK::Logs::LoggerProvider.new(resource: resource).tap do |provider|
          provider.add_log_record_processor(log_processor_for(log_exporter) ||
            OpenTelemetry::SDK::Logs::Export::BatchLogRecordProcessor.new(
              OpenTelemetry::Exporter::OTLP::Logs::LogsExporter.new
            ))
        end
      end
      new(tracer_provider, logger_provider)
    end

    # A test hands in an in-memory exporter and gets a synchronous processor.
    def self.processor_for(exporter)
      exporter && OpenTelemetry::SDK::Trace::Export::SimpleSpanProcessor.new(exporter)
    end

    def self.log_processor_for(exporter)
      exporter && OpenTelemetry::SDK::Logs::Export::SimpleLogRecordProcessor.new(exporter)
    end

    def initialize(tracer_provider, logger_provider)
      @tracer_provider = tracer_provider
      @logger_provider = logger_provider
    end

    def exports_traces? = !@tracer_provider.nil?
    def exports_logs? = !@logger_provider.nil?

    # Makes this the process-wide tracer provider and W3C trace context the
    # propagator, so an incoming traceparent is honoured.
    def install
      OpenTelemetry.propagation = OpenTelemetry::Trace::Propagation::TraceContext.text_map_propagator
      OpenTelemetry.tracer_provider = @tracer_provider if @tracer_provider
      self
    end

    def tracer
      (@tracer_provider || OpenTelemetry.tracer_provider).tracer("arith", Arith::VERSION)
    end

    def otlp_logger
      @logger_provider&.logger(name: "arith", version: Arith::VERSION)
    end

    # Sends what is buffered. Called once, on the way out.
    def shutdown
      @tracer_provider&.shutdown
      @logger_provider&.shutdown
    end
  end
end
