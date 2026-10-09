require "test_helper"

class CalcTest < ActiveSupport::TestCase
  MAX = Calc::MAX
  MIN = Calc::MIN
  DIVISION_BY_ZERO = Calc::DivisionByZero
  OVERFLOW = Calc::Overflow

  # [operation, a, b, result or the error it raises]
  CASES = [
    # The worked example from the README.
    [ :sum, 4, 1, 5 ],
    [ :sub, 4, 1, 3 ],
    [ :mul, 4, 1, 4 ],
    [ :div, 7, 2, 3 ],
    # Truncation toward zero, both signs. Ruby's own / would give -4 here.
    [ :div, -7, 2, -3 ],
    [ :div, 7, -2, -3 ],
    [ :div, -7, -2, 3 ],
    [ :div, 1, 2, 0 ],
    [ :div, -1, 2, 0 ],
    # Zero and negatives behave like integers do.
    [ :sum, -4, 1, -3 ],
    [ :sub, 1, 4, -3 ],
    [ :mul, -4, 0, 0 ],
    [ :div, 0, 5, 0 ],
    # Division by zero.
    [ :div, 1, 0, DIVISION_BY_ZERO ],
    [ :div, 0, 0, DIVISION_BY_ZERO ],
    # Overflow in every operation. Ruby would happily return a bigger number.
    [ :sum, MAX, 1, OVERFLOW ],
    [ :sum, MIN, -1, OVERFLOW ],
    [ :sub, MIN, 1, OVERFLOW ],
    [ :sub, MAX, -1, OVERFLOW ],
    [ :mul, MAX, 2, OVERFLOW ],
    [ :mul, MIN, -1, OVERFLOW ],
    [ :div, MIN, -1, OVERFLOW ],
    # The edges that do fit.
    [ :sum, MAX, 0, MAX ],
    [ :mul, MIN, 1, MIN ],
    [ :div, MIN, 1, MIN ],
    [ :div, MAX, -1, -MAX ]
  ].freeze

  test "results" do
    CASES.each do |operation, a, b, want|
      label = "#{operation} #{a} #{b}"
      if want.is_a?(Class)
        assert_raises(want, label) { Calc.public_send(operation, a, b) }
      else
        assert_equal want, Calc.public_send(operation, a, b), label
      end
    end
  end

  test "the 64-bit range" do
    assert_equal 9_223_372_036_854_775_807, MAX
    assert_equal(-9_223_372_036_854_775_808, MIN)
  end

  test "error text is what the API returns" do
    assert_equal "division by zero", DIVISION_BY_ZERO.new.message
    assert_equal "result does not fit in a 64-bit integer", OVERFLOW.new.message
  end

  test "errors name their metrics outcome" do
    assert_equal "division_by_zero", DIVISION_BY_ZERO.new.outcome
    assert_equal "overflow", OVERFLOW.new.outcome
  end
end
