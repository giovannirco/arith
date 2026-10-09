# make cover sets COVERAGE=1: line coverage of app/, lib/ and config/,
# printed as a summary and written to coverage/index.html.
if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    enable_coverage :line
    add_filter "/test/"
    add_group "app", "app/"
    add_group "lib", "lib/"
    add_group "config", "config/"
  end
end

ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

# Tests read log lines from a buffer instead of the terminal.
Arith.log = Arith::Log.new(level: "debug", out: StringIO.new)
Rails.logger = Arith.log.logger_for("rails")

module ActiveSupport
  class TestCase
    # A fresh registry per test, so counts start at zero.
    setup { Arith.metrics = Arith::Metrics.new }
  end
end
