require "logger"

module Sorbetor
  module Logging
    DEFAULT_LOG_LEVEL = Logger::INFO

    LOG_LEVELS = {
      'warn' => Logger::WARN,
      'info' => Logger::INFO,
      'debug' => Logger::DEBUG
    }

    @@logger = Logger.new(STDERR, level: DEFAULT_LOG_LEVEL)
    @@logger.formatter = proc do |severity, datetime, progname, msg|
      "[#{severity}] #{msg}\n"
    end

    module_function

    def logger
      @@logger
    end
  end
end