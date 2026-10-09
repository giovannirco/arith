# Settings. Everything comes from the environment; nothing is read from disk.
#
# ARITH_* variables are this program's own. The OTEL_* variables follow the
# OpenTelemetry specification, so a collector's documentation applies as is.
#
# Plain Ruby on purpose: config/puma.rb reads it before Rails boots.
module Arith
  class Config
    # A variable that is set but cannot be used.
    class Error < StandardError
      attr_reader :var, :value, :expected

      def initialize(var, value, expected)
        @var = var
        @value = value
        @expected = expected
        super("#{var}=#{value.inspect} is not valid: expected #{expected}")
      end
    end

    LOG_LEVELS = %w[debug info warn error].freeze

    attr_reader :host, :port, :log_level, :log_format, :shutdown_timeout,
                :traces_otlp, :logs_console, :logs_otlp, :service_name

    def self.from_env(env = ENV)
      new(env)
    end

    def initialize(env)
      @env = env
      @host, @port = parse_addr(get("ARITH_ADDR") || "0.0.0.0:8000")
      @log_level = one_of("ARITH_LOG_LEVEL", LOG_LEVELS, default: "info", expected: "debug, info, warn or error")
      @log_format = one_of("ARITH_LOG_FORMAT", %w[json text], default: "json")
      @shutdown_timeout = seconds("ARITH_SHUTDOWN_TIMEOUT", default: 10)
      @traces_otlp = one_of("OTEL_TRACES_EXPORTER", %w[none otlp], default: "none") == "otlp"
      @logs_console, @logs_otlp = parse_logs_exporter(get("OTEL_LOGS_EXPORTER") || "console")
      # Ruby's OTLP exporters speak http/protobuf only.
      one_of("OTEL_EXPORTER_OTLP_PROTOCOL", %w[http/protobuf], default: "http/protobuf")
      @service_name = get("OTEL_SERVICE_NAME") || "arith"
    end

    # "host:port" for logs, with IPv6 hosts in brackets.
    def addr
      host.include?(":") ? "[#{host}]:#{port}" : "#{host}:#{port}"
    end

    private

    # A value that is empty or only spaces counts as unset.
    def get(name)
      value = @env[name]
      value unless value.nil? || value.strip.empty?
    end

    def one_of(name, allowed, default:, expected: allowed.join(" or "))
      value = get(name) || default
      return value if allowed.include?(value)

      raise Error.new(name, value, expected)
    end

    def parse_addr(value)
      match = /\A(?:\[(?<host>[^\]]+)\]|(?<host>[^:\[\]]+)):(?<port>\d{1,5})\z/.match(value)
      port = match && match[:port].to_i
      raise Error.new("ARITH_ADDR", value, "host:port") unless port&.between?(1, 65_535)

      [ match[:host], port ]
    end

    def seconds(name, default:)
      value = get(name)
      return default if value.nil?
      return value.to_i if value.match?(/\A\d+\z/)

      raise Error.new(name, value, "a number of seconds")
    end

    def parse_logs_exporter(value)
      items = value.split(",").map(&:strip)
      unless items.all? { |item| %w[console otlp none].include?(item) }
        raise Error.new("OTEL_LOGS_EXPORTER", value, "console, otlp, console,otlp or none")
      end

      [ items.include?("console"), items.include?("otlp") ]
    end
  end
end
