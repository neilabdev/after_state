# frozen_string_literal: true

require_relative "after_state/version"
require_relative "after_state/changed"

module AfterState
  class Error < StandardError; end
  # Your code goes here...
end

require 'after_state/railtie'  if defined?(Rails::Railtie)