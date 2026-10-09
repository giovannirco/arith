require "json"
require "time"

module Arith
  # One line per event on stdout, as JSON (the default) or as readable text,
  # and the same record over OTLP when OTEL_LOGS_EXPORTER includes otlp.
  #
  #   {"time":"2026-10-09T12:00:00.123Z","level":"info","logger":"access","message":"request","status":200,...}
  #   2026-10-09T12:00:00.123Z  INFO access: request status=200 ...
  class Log
    LEVELS = { "debug" => 0, "info" => 1, "warn" => 2, "error" => 3 }.freeze
    # OpenTelemetry severity numbers for the same levels.
    SEVERITY = { "debug" => 5, "info" => 9, "warn" => 13, "error" => 17 }.freeze

    attr_reader :level
    # Set once the OpenTelemetry logger provider exists.
    attr_accessor :otlp_logger

    def initialize(level: "info", format: "json", console: true, out: $stdout, otlp_logger: nil)
      @level = level
      @threshold = LEVELS.fetch(level)
      @format = format
      @console = console
      @out = out
      @otlp_logger = otlp_logger
    end

    def debug(message, **fields) = emit("debug", message, fields)
    def info(message, **fields) = emit("info", message, fields)
    def warn(message, **fields) = emit("warn", message, fields)
    def error(message, **fields) = emit("error", message, fields)

    def enabled?(level) = LEVELS.fetch(level) >= @threshold

    # `logger` names the part of the program speaking (access, puma, rails).
    # `context` is the OpenTelemetry context whose span the record belongs to.
    def emit(level, message, fields, logger: "arith", context: nil)
      return unless enabled?(level)

      fields = fields.compact
      fields[:logger] = logger
      time = Time.now.utc
      @out.write(line(time, level, message, fields) + "\n") if @console
      export(time, level, message, fields, context) if @otlp_logger
      nil
    end

    # One line in this format, without the newline, for a writer that adds
    # its own (Puma's log_formatter).
    def format(level, message, logger:)
      line(Time.now.utc, level, message, { logger: logger })
    end

    # A ::Logger for Rails and Puma, so their few lines share this format.
    def logger_for(name, level: "warn")
      log = self
      ::Logger.new(@out, level: level).tap do |logger|
        logger.formatter = proc do |severity, _time, _progname, message|
          sev = severity.downcase
          sev = "error" unless LEVELS.key?(sev)
          log.emit(sev, message.to_s.strip, {}, logger: name)
          ""
        end
      end
    end

    private

    def line(time, level, message, fields)
      stamp = time.iso8601(3)
      if @format == "json"
        JSON.generate({ time: stamp, level: level, message: message }.merge(fields))
      else
        fields = fields.dup
        logger = fields.delete(:logger)
        pairs = fields.map { |k, v| "#{k}=#{v.is_a?(String) && v.match?(/\s|\A\z/) ? v.inspect : v}" }
        "#{stamp} #{level.upcase.rjust(5)} #{logger}: #{[ message, *pairs ].join(' ')}"
      end
    end

    def export(time, level, message, fields, context)
      attributes = fields.transform_keys(&:to_s).transform_values { |v| v.is_a?(Numeric) ? v : v.to_s }
      options = { timestamp: time, severity_text: level.upcase, severity_number: SEVERITY.fetch(level),
                  body: message, attributes: attributes }
      options[:context] = context if context
      @otlp_logger.on_emit(**options)
    end
  end
end
