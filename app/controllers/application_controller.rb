# Every response body is JSON written with the standard library's generator,
# so it reads exactly like the README's examples ({"result":5}).
class ApplicationController < ActionController::API
  private

  def render_json(body, status: :ok)
    render json: JSON.generate(body), status: status
  end

  # An error the client can fix: {"error": "<why>"}. The access log line
  # carries the same text.
  def render_error(message, status: :bad_request)
    request.env["arith.error"] = message
    render_json({ error: message }, status: status)
  end
end
