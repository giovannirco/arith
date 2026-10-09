require "test_helper"

# The HTTP contract, end to end through the Rails stack: the same requests the
# README documents, with the bodies it promises.
class ApiTest < ActionDispatch::IntegrationTest
  def assert_json(status, body, uri)
    get uri
    assert_response status, uri
    assert_equal body, response.body, uri
    assert_equal "application/json", response.media_type, uri
  end

  test "the worked example" do
    assert_json 200, '{"result":5}', "/api/sum?term_one=4&term_two=1"
    assert_json 200, '{"result":3}', "/api/sub?term_one=4&term_two=1"
    assert_json 200, '{"result":4}', "/api/mul?term_one=4&term_two=1"
    assert_json 200, '{"result":3}', "/api/div?term_one=7&term_two=2"
  end

  test "division truncates toward zero" do
    assert_json 200, '{"result":-3}', "/api/div?term_one=-7&term_two=2"
    assert_json 200, '{"result":-3}', "/api/div?term_one=7&term_two=-2"
  end

  test "errors are 400 with a reason" do
    [
      [ "/api/div?term_one=1&term_two=0", '{"error":"division by zero"}' ],
      [ "/api/sum?term_one=abc&term_two=1", '{"error":"term_one must be an integer, got \"abc\""}' ],
      [ "/api/sum?term_one=1&term_two=1.5", '{"error":"term_two must be an integer, got \"1.5\""}' ],
      [ "/api/sum?term_one=1", '{"error":"term_two is required"}' ],
      [ "/api/mul", '{"error":"term_one is required"}' ],
      [ "/api/sum?term_one=9223372036854775807&term_two=1", '{"error":"result does not fit in a 64-bit integer"}' ],
      [ "/api/mul?term_one=-9223372036854775808&term_two=-1", '{"error":"result does not fit in a 64-bit integer"}' ],
      [ "/api/div?term_one=-9223372036854775808&term_two=-1", '{"error":"result does not fit in a 64-bit integer"}' ],
      [ "/api/sub?term_one=99999999999999999999&term_two=1",
        '{"error":"term_one does not fit in a 64-bit integer, got \"99999999999999999999\""}' ]
    ].each { |uri, body| assert_json 400, body, uri }
  end

  test "a query string that is not UTF-8 is a 400 too" do
    assert_json 400, '{"error":"bad request"}', "/api/sum?term_one=%ff&term_two=1"
  end

  test "the error text reaches the access log" do
    get "/api/div?term_one=1&term_two=0"
    assert_equal "division by zero", request.env["arith.error"]
  end

  test "healthz" do
    assert_json 200, '{"status":"ok"}', "/healthz"
  end

  test "unknown paths and methods are JSON too" do
    assert_json 404, '{"error":"not found"}', "/api/pow?term_one=2&term_two=3"
    assert_json 404, '{"error":"not found"}', "/api/sum.json?term_one=2&term_two=3"

    post "/api/sum?term_one=1&term_two=2"
    assert_response 405
    assert_equal '{"error":"method not allowed"}', response.body
  end

  test "HEAD answers like GET, without a body" do
    head "/healthz"
    assert_response 200
    assert_empty response.body
  end

  test "an exception that escapes a controller is a JSON 500" do
    HealthController.class_eval { alias_method :original_show, :show }
    HealthController.define_method(:show) { raise "boom" }
    get "/healthz"
    assert_response 500
    assert_equal '{"error":"internal server error"}', response.body
  ensure
    HealthController.class_eval do
      alias_method :show, :original_show
      remove_method :original_show
    end
  end
end
