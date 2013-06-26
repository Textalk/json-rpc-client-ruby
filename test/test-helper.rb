require 'simplecov'
require 'simplecov-rcov'
require 'logger'
require 'coveralls'

Coveralls.wear!

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter[
  SimpleCov::Formatter::RcovFormatter,
  Coveralls::SimpleCov::Formatter
]
SimpleCov.command_name 'bacon'
SimpleCov.start do
  add_filter '/vendor/'
  add_filter '/test/'
end

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
