# Unknown paths and wrong methods get JSON too, like every other answer.
class ErrorsController < ApplicationController
  def not_found
    render_error("not found", status: :not_found)
  end

  def method_not_allowed
    render_error("method not allowed", status: :method_not_allowed)
  end
end
