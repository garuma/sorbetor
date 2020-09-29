# frozen_string_literal: true

require "backport"
require "optparse"

module Sorbetor
  class Server
    def self.start(argv)
      options = {}
      OptionParser.new do |opts|
        opts.banner = "Usage: server.rb [options]"

        opts.on(:OPTIONAL, "--stdio", "Start the server in stdio mode") do
          options[:mode] = :stdio
        end

        opts.on("--socket=[port]", Integer, "Start the server in TCP mode, supply port") do |port|
          options[:mode] = :socket
          options[:port] = port
        end

        opts.on("-h", "--help", "Prints this help") do
          puts opts
          exit
        end
      end.parse!(argv)

      options[:mode] = :stdio unless options[:mode]

      Backport.run do
        case options
          in { mode: :stdio }
            Signal.trap("INT") do
              Backport.stop
            end
            Signal.trap("TERM") do
              Backport.stop
            end
            Backport.prepare_stdio_server adapter: Sorbetor::LanguageServer::Adapter
          in { mode: :socket, port: }
            Backport.prepare_tcp_server(host: "localhost", port: port, adapter: Sorbetor::LanguageServer::Adapter)
            Logging.logger.warn "Listening on port #{port}"
        end

        Logging.logger.warn "Running on PID #{Process.pid}"
      end

      Logging.logger.info "Bye!"
    end
  end
end
