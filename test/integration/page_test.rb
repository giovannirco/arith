require "test_helper"

class PageTest < ActionDispatch::IntegrationTest
  test "the page" do
    get "/"
    assert_response 200
    assert_equal "text/html; charset=utf-8", response.content_type
    assert_includes response.headers["content-security-policy"], "default-src 'none'"
    assert_equal "nosniff", response.headers["x-content-type-options"]
    assert_includes response.body, "<title>arith</title>"
    %w[sum sub mul div].each { |op| assert_includes response.body, %(data-op="#{op}"), "#{op} button" }
  end

  test "its stylesheet and script" do
    get "/style.css"
    assert_response 200
    assert_equal "text/css; charset=utf-8", response.content_type
    assert_includes response.body, "--accent"

    get "/app.js"
    assert_response 200
    assert_equal "text/javascript; charset=utf-8", response.content_type
    assert_includes response.body, "/api/${operation}"
  end
end
