require "test_helper"

class ConfigTest < ActiveSupport::TestCase
  def config(vars = {}) = Arith::Config.from_env(vars)

  test "defaults" do
    c = config
    assert_equal "0.0.0.0", c.host
    assert_equal 8000, c.port
    assert_equal "0.0.0.0:8000", c.addr
    assert_equal "info", c.log_level
    assert_equal "json", c.log_format
    assert_equal 10, c.shutdown_timeout
    assert_not c.traces_otlp
    assert c.logs_console
    assert_not c.logs_otlp
    assert_equal "arith", c.service_name
  end

  test "everything set" do
    c = config(
      "ARITH_ADDR" => "127.0.0.1:9000",
      "ARITH_LOG_LEVEL" => "debug",
      "ARITH_LOG_FORMAT" => "text",
      "ARITH_SHUTDOWN_TIMEOUT" => "3",
      "OTEL_TRACES_EXPORTER" => "otlp",
      "OTEL_LOGS_EXPORTER" => "console, otlp",
      "OTEL_EXPORTER_OTLP_PROTOCOL" => "http/protobuf",
      "OTEL_SERVICE_NAME" => "calc"
    )
    assert_equal "127.0.0.1:9000", c.addr
    assert_equal "debug", c.log_level
    assert_equal "text", c.log_format
    assert_equal 3, c.shutdown_timeout
    assert c.traces_otlp
    assert c.logs_console
    assert c.logs_otlp
    assert_equal "calc", c.service_name
  end

  test "an IPv6 address keeps its brackets" do
    c = config("ARITH_ADDR" => "[::]:8000")
    assert_equal "::", c.host
    assert_equal "[::]:8000", c.addr
  end

  test "empty values mean unset" do
    c = config("ARITH_ADDR" => "  ", "OTEL_LOGS_EXPORTER" => "")
    assert_equal 8000, c.port
    assert c.logs_console
  end

  test "logs none turns everything off" do
    c = config("OTEL_LOGS_EXPORTER" => "none")
    assert_not c.logs_console
    assert_not c.logs_otlp
  end

  test "bad values name the variable" do
    [
      [ "ARITH_ADDR", "eight thousand", "host:port" ],
      [ "ARITH_ADDR", "0.0.0.0:99999", "host:port" ],
      [ "ARITH_LOG_LEVEL", "loud", "debug, info, warn or error" ],
      [ "ARITH_LOG_FORMAT", "yaml", "json or text" ],
      [ "ARITH_SHUTDOWN_TIMEOUT", "soon", "a number of seconds" ],
      [ "OTEL_TRACES_EXPORTER", "jaeger", "none or otlp" ],
      [ "OTEL_LOGS_EXPORTER", "syslog", "console, otlp, console,otlp or none" ],
      # Ruby's OTLP exporters have no gRPC transport.
      [ "OTEL_EXPORTER_OTLP_PROTOCOL", "grpc", "http/protobuf" ]
    ].each do |var, value, expected|
      error = assert_raises(Arith::Config::Error) { config(var => value) }
      assert_equal var, error.var
      assert_equal value, error.value
      assert_equal expected, error.expected
      assert_equal "#{var}=#{value.inspect} is not valid: expected #{expected}", error.message
    end
  end
end
