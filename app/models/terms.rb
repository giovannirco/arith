require "json"

# Reads term_one and term_two from a query string.
#
# The query is decoded here rather than through Rails' params so that every
# malformed request still gets the same {"error": ...} shape, and so the
# message can quote exactly what was sent.
module Terms
  # An error the client can fix. The message is the API's error text.
  class Invalid < StandardError; end

  # An optional sign followed by ASCII digits.
  INTEGER = /\A[+-]?[0-9]+\z/

  module_function

  # Returns [term_one, term_two] as Integers, or raises Invalid for the first
  # term that is missing or unusable.
  def parse(query)
    values = decode(query.to_s)
    [ term("term_one", values["term_one"]), term("term_two", values["term_two"]) ]
  end

  def term(name, value)
    raise Invalid, "#{name} is required" if value.nil?
    raise Invalid, "#{name} must be an integer, got #{quote(value)}" unless value.match?(INTEGER)

    number = Integer(value, 10)
    raise Invalid, "#{name} does not fit in a 64-bit integer, got #{quote(value)}" unless number.between?(Calc::MIN, Calc::MAX)

    number
  end

  # application/x-www-form-urlencoded: pairs split on &, + is a space, %XX is
  # a byte. A key that repeats keeps its last value; other keys are ignored.
  def decode(query)
    query.split("&").each_with_object({}) do |pair, values|
      next if pair.empty?

      key, value = pair.split("=", 2)
      values[unescape(key)] = unescape(value.to_s)
    end
  end

  # Bytes that are not UTF-8 become U+FFFD, so the error text stays valid JSON.
  def unescape(text)
    text.b.tr("+", " ").gsub(/%(\h\h)/n) { Regexp.last_match(1).hex.chr }.force_encoding(Encoding::UTF_8).scrub
  end

  # The value in double quotes, escaped the way JSON escapes a string.
  def quote(value) = JSON.generate(value)
end
