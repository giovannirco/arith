require "test_helper"

class TermsTest < ActiveSupport::TestCase
  def assert_invalid(message, query)
    error = assert_raises(Terms::Invalid, query) { Terms.parse(query) }
    assert_equal message, error.message, query
  end

  test "parses both terms" do
    assert_equal [ 4, 1 ], Terms.parse("term_one=4&term_two=1")
    assert_equal [ 4, 1 ], Terms.parse("term_two=1&term_one=4")
    assert_equal [ 0, 0 ], Terms.parse("term_one=0&term_two=0&extra=ignored")
    assert_equal [ Calc::MAX, Calc::MIN ], Terms.parse("term_one=9223372036854775807&term_two=-9223372036854775808")
  end

  test "a plus sign travels as %2B; a bare + is a space" do
    assert_equal [ -7, 2 ], Terms.parse("term_one=-7&term_two=%2B2")
    assert_invalid 'term_two must be an integer, got " 2"', "term_one=-7&term_two=+2"
  end

  test "leading zeros are decimal, not octal" do
    assert_equal [ 10, 8 ], Terms.parse("term_one=010&term_two=0008")
  end

  test "repeated keys take the last value" do
    assert_equal [ 2, 3 ], Terms.parse("term_one=1&term_one=2&term_two=3")
  end

  test "missing terms" do
    assert_invalid "term_one is required", ""
    assert_invalid "term_one is required", "term_two=1"
    assert_invalid "term_two is required", "term_one=1"
    assert_invalid "term_one is required", "term_one[]=1&term_two=1"
  end

  test "non-integers" do
    assert_invalid 'term_one must be an integer, got "abc"', "term_one=abc&term_two=1"
    assert_invalid 'term_two must be an integer, got "1.5"', "term_one=1&term_two=1.5"
    assert_invalid 'term_one must be an integer, got ""', "term_one=&term_two=1"
    assert_invalid 'term_one must be an integer, got ""', "term_one&term_two=1"
    assert_invalid 'term_one must be an integer, got " 1"', "term_one=%201&term_two=1"
    assert_invalid 'term_two must be an integer, got "-"', "term_one=1&term_two=-"
    # What Ruby's Integer() would accept and the API does not.
    assert_invalid 'term_one must be an integer, got "0x1f"', "term_one=0x1f&term_two=1"
    assert_invalid 'term_one must be an integer, got "1_000"', "term_one=1_000&term_two=1"
    assert_invalid 'term_one must be an integer, got "1\n"', "term_one=1%0A&term_two=1"
    assert_invalid 'term_one must be an integer, got "١"', "term_one=%D9%A1&term_two=1"
  end

  test "the quoted value is escaped like a JSON string" do
    assert_invalid 'term_one must be an integer, got "a\"b#{c}"', "term_one=a%22b%23%7Bc%7D&term_two=1"
  end

  test "bytes that are not UTF-8 become U+FFFD" do
    assert_invalid "term_one must be an integer, got \"�\"", "term_one=%ff&term_two=1"
  end

  test "integers that do not fit say so" do
    assert_invalid 'term_one does not fit in a 64-bit integer, got "9223372036854775808"',
                   "term_one=9223372036854775808&term_two=1"
    assert_invalid 'term_two does not fit in a 64-bit integer, got "-99999999999999999999"',
                   "term_one=1&term_two=-99999999999999999999"
  end

  test "the first problem wins" do
    assert_invalid 'term_one must be an integer, got "x"', "term_one=x&term_two=y"
  end
end
