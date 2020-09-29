# frozen_string_literal: true

require "backport"
require "solargraph/language_server/transport/data_reader"

module Sorbetor
  module LanguageServer
    class Adapter < Backport::Adapter
      def opening
        @host = Sorbetor::LanguageServer::SorbetorHost.new
        @host.add_observer(self)
        @host.start
        @data_reader = Sorbetor::LanguageServer::DataReader.new
        @data_reader.set_message_handler do |message|
          process message
        end
      end

      def closing
        @host&.stop
      end

      # @param data [String]
      def receiving(data)
        @data_reader.receive data
      end

      def update
        if @host.stopped?
          shutdown
        else
          tmp = @host.flush
          write tmp unless tmp.empty?
        end
      end

      # @param request [String]
      # @return [void]
      private def process(request)
        @host.receive(request)
      end

      private def shutdown
        Backport.stop
      end
    end
  end
end
