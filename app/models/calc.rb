# The four operations on signed 64-bit integers. No HTTP in here.
#
# Ruby integers never overflow, so every result is checked against the 64-bit
# range here: a result that does not fit is an error, not a bigger number.
#
# To add or change an operation: edit its method, add a row to the table in
# test/models/calc_test.rb, route it in config/routes.rb and give the page a
# button in web/index.html.
module Calc
  MIN = -(2**63)
  MAX = (2**63) - 1

  # Why an operation could not produce an integer. The message is what the
  # API returns; the outcome is the label on arith_operations_total.
  class Error < StandardError
    def outcome = self.class::OUTCOME
  end

  class DivisionByZero < Error
    OUTCOME = "division_by_zero".freeze
    def initialize(message = "division by zero") = super
  end

  class Overflow < Error
    OUTCOME = "overflow".freeze
    def initialize(message = "result does not fit in a 64-bit integer") = super
  end

  module_function

  def sum(a, b) = fit(a + b)

  def sub(a, b) = fit(a - b)

  def mul(a, b) = fit(a * b)

  # Integer division, truncating toward zero: 7 / 2 = 3, -7 / 2 = -3.
  # Ruby's own / rounds toward negative infinity, so the sign is put back on
  # the quotient of the absolute values. MIN / -1 is the one quotient that
  # does not fit.
  def div(a, b)
    raise DivisionByZero if b.zero?

    quotient = a.abs / b.abs
    fit(a.negative? == b.negative? ? quotient : -quotient)
  end

  def fit(n)
    raise Overflow unless n.between?(MIN, MAX)

    n
  end
end
