require "test_helper"

class MetricsTest < ActiveSupport::TestCase
  test "renders requests, operations and build info" do
    m = Arith::Metrics.new
    m.observe_request(method: "GET", route: "/api/sum", status: 200, seconds: 0.002)
    m.observe_request(method: "GET", route: "/api/sum", status: 200, seconds: 0.003)
    m.observe_request(method: "GET", route: "/api/div", status: 400, seconds: 0.0003)
    m.observe_operation(:sum, "ok")
    m.observe_operation(:sum, "ok")
    m.observe_operation(:div, Calc::DivisionByZero.new.outcome)
    m.observe_operation(:mul, Calc::Overflow.new.outcome)
    m.observe_operation(:sub, "bad_input")

    text = m.render
    [
      'http_requests_total{method="GET",route="/api/sum",status="200"} 2.0',
      'http_requests_total{method="GET",route="/api/div",status="400"} 1.0',
      'http_request_duration_seconds_count{method="GET",route="/api/sum"} 2.0',
      'http_request_duration_seconds_bucket{method="GET",route="/api/div",le="0.0005"} 1.0',
      'arith_operations_total{operation="sum",outcome="ok"} 2.0',
      'arith_operations_total{operation="div",outcome="division_by_zero"} 1.0',
      'arith_operations_total{operation="mul",outcome="overflow"} 1.0',
      'arith_operations_total{operation="sub",outcome="bad_input"} 1.0',
      %(arith_build_info{version="#{Arith::VERSION}"} 1.0)
    ].each { |line| assert_includes text, line }
  end

  test "outcomes are a fixed set" do
    assert_raises(ArgumentError) { Arith::Metrics.new.observe_operation(:sum, "term_one is required") }
  end
end
