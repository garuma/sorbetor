# frozen_string_literal: true

# Extracted and refactored to be made generic from solargraph's Host

require "observer"
require "set"
require "solargraph/language_server/uri_helpers"
require "solargraph/language_server/error_codes"

module Sorbetor
  module LanguageServer
    class BaseHost
      include Observable
      include Logging
      include Solargraph::LanguageServer::UriHelpers

      attr_writer :client_capabilities

      def initialize
        @cancel_semaphore = Mutex.new
        @buffer_semaphore = Mutex.new
        @register_semaphore = Mutex.new
        @cancel = []
        @buffer = ""
        @stopped = true
        @next_request_id = 0
        @dynamic_capabilities = Set.new
        @registered_capabilities = Set.new
      end

      def start
        return unless stopped?

        @stopped = false
      end

      def configure(update)
        return if update.nil?

        options.merge! update
      end

      def options
        @options ||= default_configuration
      end

      def cancel(id)
        @cancel_semaphore.synchronize { @cancel.push id }
      end

      def cancel?(id)
        result = false
        @cancel_semaphore.synchronize { result = @cancel.include? id }
        result
      end

      def clear(id)
        @cancel_semaphore.synchronize { @cancel.delete id }
      end

      # rubocop:disable Metrics/CyclomaticComplexity
      # rubocop:disable Metrics/PerceivedComplexity
      def receive(request)
        case request
          in { method: } # A classic client -> server request
            logger.info "Server received #{method}"
            logger.debug request
            message_name = lsp_method_to_ruby_name(method)
            req_id = request[:id]
            if message_name.nil? || !respond_to?(message_name)
              unless method.start_with?("$/")
                reply_error(
                  request[:id],
                  Solargraph::LanguageServer::ErrorCodes::METHOD_NOT_FOUND,
                  "Method not found: #{method}"
                )
              end
            else
              begin
                result = public_send(message_name, request[:params])
                return if req_id.nil? || result.nil?

                reply_result(req_id, result)
              rescue StandardError => e
                logger.warn "Error processing request: [#{e.class}] #{e.message}"
                logger.warn e.backtrace.join("\n")
                reply_error(req_id, Solargraph::LanguageServer::ErrorCodes::INTERNAL_ERROR, "[#{e.class}] #{e.message}")
              end
            end
          in { id: req_id } # Response from the client about a request we sent
            requests.dig(req_id, :callback)&.call(request[:result])
            requests.delete req_id
          else
            logger.warn "Invalid message received."
            logger.debug request
        end
      end
      # rubocop:enable Metrics/CyclomaticComplexity
      # rubocop:enable Metrics/PerceivedComplexity

      def lsp_initialize(params)
        dynamic_registration_methods = {
          textDocument: %I[
            completion signatureHelp onTypeFormatting
            hover formatting documentSymbol definition
            rename references foldingRange codeAction
          ],
          workspace: %I[symbol],
        }
        dynamic_registration_methods.map do |section, methods|
          methods.map do |method|
            if params.dig(:capabilities, section, method, :dynamicRegistration)
              allow_registration("#{section}/#{method}")
            end
          end
        end

        {
          capabilities: initial_server_capabilities,
          serverInfo: {
            name: "Sorbetor",
            version: Sorbetor::VERSION,
          },
        }
      end

      def shutdown(_params); end

      def exit(_params)
        stop
      end

      def initial_server_capabilities
        nil
      end

      def reply_error(id, code, message)
        reply(id) do |response|
          response[:error] = {
            code: code,
            message: message,
          }
        end
      end

      def reply_result(id, result)
        reply(id) { |response| response[:result] = result }
      end

      def flush
        tmp = ""
        @buffer_semaphore.synchronize do
          tmp = @buffer.clone
          @buffer.clear
        end
        tmp
      end

      def send_notification(method, params)
        response = {
          jsonrpc: "2.0",
          method: method,
          params: params,
        }
        json = response.to_json
        envelope = "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
        queue envelope
        logger.info "Server sent #{method}"
        logger.debug params
      end

      # Send a request to the client and execute the provided block to process
      # the response. If an ID is not provided, the host will use an auto-
      # incrementing integer.
      #
      # @param method [String] The message method
      # @param params [Hash] The method parameters
      # @param block [Proc] The block that processes the response
      # @yieldparam [Hash] The result sent by the client
      # @return [void]
      def send_request(method, params, &block)
        message = {
          jsonrpc: "2.0",
          method: method,
          params: params,
          id: @next_request_id,
        }
        json = message.to_json
        requests[@next_request_id] = { id: @next_request_id, callback: block_given? ? Proc.new(&block) : nil }
        envelope = "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
        queue envelope
        @next_request_id += 1
        logger.info "Server sent #{method}"
        logger.debug params
      end

      # Register the methods as capabilities with the client.
      # This method will avoid duplicating registrations and ignore methods
      # that were not flagged for dynamic registration by the client.
      #
      # @param methods [Array<String>] The methods to register
      # @return [void]
      def register_capabilities(methods)
        logger.debug "Registering capabilities: #{methods}"
        registrations = methods.select { |m| can_register?(m) and !registered?(m) }.map do |m|
          @registered_capabilities.add m
          {
            id: m,
            method: m,
            registerOptions: dynamic_capability_options_for(m),
          }
        end
        return if registrations.empty?

        @register_semaphore.synchronize do
          send_request("client/registerCapability", {
            registrations: registrations,
          })
        end
      end

      def dynamic_capability_options_for(capability)
        default_dynamic_capability_options[capability]
      end

      # Unregister the methods with the client.
      # This method will avoid duplicating unregistrations and ignore methods
      # that were not flagged for dynamic registration by the client.
      #
      # @param methods [Array<String>] The methods to unregister
      # @return [void]
      def unregister_capabilities(methods)
        logger.debug "Unregistering capabilities: #{methods}"
        unregisterations = methods.select { |m| registered?(m) }.map do |m|
          @registered_capabilities.delete m
          {
            id: m,
            method: m,
          }
        end
        return if unregisterations.empty?

        @register_semaphore.synchronize do
          send_request "client/unregisterCapability", {
            unregisterations: unregisterations,
          }
        end
      end

      # Flag a method as available for dynamic registration.
      #
      # @param method [String] The method name, e.g., 'textDocument/completion'
      # @return [void]
      def allow_registration(method)
        @register_semaphore.synchronize do
          @dynamic_capabilities.add method
        end
      end

      # True if the specified LSP method can be dynamically registered.
      #
      # @param method [String]
      # @return [Boolean]
      def can_register?(method)
        @dynamic_capabilities.include?(method)
      end

      # True if the specified method has been registered.
      #
      # @param method [String] The method name, e.g., 'textDocument/completion'
      # @return [Boolean]
      def registered?(method)
        @registered_capabilities.include?(method)
      end

      # @return [void]
      def stop
        return if @stopped

        @stopped = true
        changed
        notify_observers
      end

      def stopped?
        @stopped
      end

      # Send a notification to the client.
      #
      # @param text [String]
      # @param type [Integer] A MessageType constant
      # @return [void]
      def show_message(text, type = LanguageServer::MessageTypes::INFO)
        send_notification "window/showMessage", {
          type: type,
          message: text,
        }
      end

      # Send a notification with optional responses.
      #
      # @param text [String]
      # @param type [Integer] A MessageType constant
      # @param actions [Array<String>] Response options for the client
      # @param block The block that processes the response
      # @yieldparam [String] The action received from the client
      # @return [void]
      def show_message_request(text, type, actions, &block)
        send_request "window/showMessageRequest", {
          type: type,
          message: text,
          actions: actions,
        }, &block
      end

      # Get a list of IDs for server requests that are waiting for responses
      # from the client.
      #
      # @return [Array<Integer>]
      def pending_requests
        requests.keys
      end

      # @return [Hash{String => Object}]
      def default_configuration
        {
          "completion" => true,
          "hover" => true,
          "symbols" => true,
          "definitions" => true,
          "rename" => true,
          "references" => true,
          "autoformat" => false,
          "diagnostics" => false,
          "formatting" => false,
          "folding" => true,
          "logLevel" => "warn",
        }
      end

      def client_capabilities
        @client_capabilities ||= {}
      end

      def lsp_method_to_ruby_name(method)
        BaseHost.default_lsp_method_to_ruby_name(method)
      end

      def self.default_lsp_method_to_ruby_name(method)
        snake_caser = lambda { |str|
          result = String.new(capacity: str.length)
          str.each_char do |c|
            if ("a".."z").include? c then result.concat c
            else result.concat("_", c.downcase)
            end
          end
          result
        }
        case method.split "/"
          in [name] if name == "initialize" # special scenario since we don't want to mistake with ctor
            "lsp_initialize"
          in [name]
            name
          in [base, suffix] if base == "$"
            "_#{snake_caser.call(suffix)}"
          in [base, suffix]
            "#{snake_caser.call(base)}_#{snake_caser.call(suffix)}"
          else
            nil
        end
      end

      private def reply(id)
        response = {
          jsonrpc: "2.0",
          id: id,
        }
        yield response
        json = response.to_json
        envelope = "Content-Length: #{json.bytesize}\r\n\r\n#{json}"
        logger.debug envelope
        queue envelope
        clear id
        nil
      end

      private def queue(message)
        @buffer_semaphore.synchronize { @buffer += message }
        changed
        notify_observers
      end

      # A hash of client requests by ID. The host uses this to keep track of
      # pending responses.
      #
      # @return [Hash{Integer => Hash}]
      private def requests
        @requests ||= {}
      end

      # @param path [String]
      # @return [String]
      private def normalize_separators(path)
        return path if File::ALT_SEPARATOR.nil?

        path.gsub(File::ALT_SEPARATOR, File::SEPARATOR)
      end

      # @return [Hash]
      private def default_dynamic_capability_options
        @default_dynamic_capability_options ||= {
          # textDocumentSync: 2, # @todo What should this be?
          "textDocument/completion" => {
            resolveProvider: true,
            triggerCharacters: [".", ":", "@"],
          },
          # hoverProvider: true,
          # definitionProvider: true,
          "textDocument/signatureHelp" => {
            triggerCharacters: ["(", ",", " "],
          },
          # documentFormattingProvider: true,
          "textDocument/onTypeFormatting" => {
            firstTriggerCharacter: "{",
            moreTriggerCharacter: ["("],
          },
          # documentSymbolProvider: true,
          # workspaceSymbolProvider: true,
          # workspace: {
          # workspaceFolders: {
          # supported: true,
          # changeNotifications: true
          # }
          # }
          "textDocument/definition" => {
            definitionProvider: true,
          },
          "textDocument/references" => {
            referencesProvider: true,
          },
          "textDocument/rename" => {
            renameProvider: prepare_rename? ? { prepareProvider: true } : true,
          },
          "textDocument/documentSymbol" => {
            documentSymbolProvider: true,
          },
          "workspace/symbol" => {
            workspaceSymbolProvider: true,
          },
          "textDocument/formatting" => {
            formattingProvider: true,
          },
          "textDocument/foldingRange" => {
            foldingRangeProvider: true,
          },
          "textDocument/codeAction" => {
            codeActionProvider: true,
          },
        }
      end
    end
  end
end
