require 'simplecov'
require 'simplecov-rcov'
require 'logger'

SimpleCov.formatter = SimpleCov::Formatter::RcovFormatter
SimpleCov.command_name 'bacon'
SimpleCov.start

# A small custom logger for the tests, all log messages are saved to an array.
class CustomLogger < Logger
  attr_reader :logs
  def initialize()
    @logs = []
  end

  def debug(message)
    @logs << message
  end

  def error(message)
    @logs << message
  end
end