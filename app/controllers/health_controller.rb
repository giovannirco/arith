# GET /healthz, for both the liveness and the readiness probe. If Rails
# answers at all, the process can do arithmetic.
class HealthController < ApplicationController
  def show
    render_json({ status: "ok" })
  end
end
