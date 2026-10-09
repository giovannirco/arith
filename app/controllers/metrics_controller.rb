# GET /metrics, for Prometheus to scrape. Nothing is pushed anywhere.
class MetricsController < ApplicationController
  def show
    render plain: Arith.metrics.render, content_type: Arith::Metrics::CONTENT_TYPE
  end
end
