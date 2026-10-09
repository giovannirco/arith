# Puma loads this. config/puma.rb holds the listen address and shutdown.
require_relative "config/environment"

run Rails.application
