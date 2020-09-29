# frozen_string_literal: true

require "json"

module Sorbetor
  module LanguageServer
    class DataReader < Solargraph::LanguageServer::Transport::DataReader
      # Override this method to ensure JSON parsing uses symbolication so that our pattern matching works
      def parse_message_from_buffer
        begin
          msg = JSON.parse(@buffer, symbolize_names: true)
          @message_handler&.call msg
        rescue JSON::ParserError => e
          Logging.logger.warn "Failed to parse request: #{e.message}"
          Logging.logger.debug "Buffer: #{@buffer}"
        ensure
          @buffer.clear
          @in_header = true
          @content_length = 0
        end
      end
    end
  end
end
