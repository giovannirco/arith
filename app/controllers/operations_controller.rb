# GET /api/{sum,sub,mul,div}?term_one=<int>&term_two=<int>
#
# {"result": <int>} on success. A missing or non-integer term, division by
# zero and a result outside 64 bits are 400 {"error": "<why>"}.
class OperationsController < ApplicationController
  def sum = operate(:sum)
  def sub = operate(:sub)
  def mul = operate(:mul)
  def div = operate(:div)

  private

  # Parses the two terms, applies the operation, counts the outcome.
  def operate(operation)
    a, b = Terms.parse(request.query_string)
    result = Calc.public_send(operation, a, b)
    Arith.metrics.observe_operation(operation, "ok")
    render_json({ result: result })
  rescue Terms::Invalid => e
    Arith.metrics.observe_operation(operation, "bad_input")
    render_error(e.message)
  rescue Calc::Error => e
    Arith.metrics.observe_operation(operation, e.outcome)
    render_error(e.message)
  end
end
