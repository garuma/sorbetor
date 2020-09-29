# frozen_string_literal: true

module Sorbetor
  module LanguageServer
    class SorbetorHost < BaseHost
      include Sorbetor::Utils::RangeHelpers

      def initialize
        super
        @opened_documents = {}
      end

      def initial_server_capabilities
        {
          textDocumentSync: {
            openClose: true,
            change: 2, # Incremental
          },
        }
      end

      def initialized(_params)
        register_capabilities %w[textDocument/completion]
      end

      def dynamic_capability_options_for(method)
        return super.dynamic_capability_options_for(method) unless method == "textDocument/completion"

        {
          resolveProvider: false,
          triggerCharacters: ["{", "."],
        }
      end

      def text_document_did_open(params)
        case params
          in { textDocument: { uri:, languageId:, text: }}
            @opened_documents[uri] = Text::TextDocument.from_s(uri_to_file(uri), text)
        end
      end

      def text_document_did_close(params)
        case params
          in { textDocument: { uri: } }
            @opened_documents.delete(uri)
        end
      end

      def text_document_did_change(params)
        case params
          in { textDocument: { uri:, version: }, contentChanges: }
            doc = @opened_documents[uri]
            return if doc.nil?

            buffer = doc.buffer
            snapshot = buffer.current_snapshot
            doc.buffer.apply_changes(contentChanges.map do |change|
              change_range = lsp_range_to_range(snapshot, change[:range])
              new_text = change[:text]
              Sorbetor::Text::TextChange.new(range: change_range, new_text: new_text)
            end)
        end
      end

      def text_document_completion(params)
        case params
          in { context:, textDocument: { uri: }, position: { line:, character: } }
            doc = @opened_documents[uri]
            return empty_completions if doc.nil?

            snapshot = doc.buffer.current_snapshot
            parsed_document = Sorbetor::Parsing::ParsedDocument.from_snapshot(snapshot)

            return empty_completions unless parsed_document.valid?

            method_def = parsed_document.get_next_method_definition_at_line(line + 1)
            return empty_completions if method_def.nil?

            insertion_text = get_insertion_text_for_method(method_def)
            return empty_completions if insertion_text.nil? || insertion_text.empty?

            {
              isIncomplete: false,
              items: [
                {
                  label: get_label_for_method(method_def),
                  type: 25,
                  insertText: insertion_text,
                  insertTextFormat: 2,
                },
              ],
            }
        end
      end

      private def empty_completions
        @empty_completions ||= {
          isIncomplete: false,
          items: [],
        }
      end

      private def get_label_for_method(method)
        params_part =
          if method.params?
            method.params.map { |name| "#{name}: ?" }.join(", ")
          else ""
          end
        returns_part = method.void? ? "void" : method.returns
        returns_part = "?" if returns_part.nil?

        "(#{params_part}) ⭢ #{returns_part}"
      end

      private def get_insertion_text_for_method(method)
        params_part =
          if method.params?
            plist = method.params.each_with_index.map { |name, index| "#{name}: $#{index + 1}" }.join(", ")
            "params(#{plist})"
          else ""
          end
        returns_part = method.returns
        if method.void?
          "#{params_part}.void"
        elsif returns_part
          "#{params_part}.returns(#{returns_part})"
        else
          params_part
        end
      end

      private def lsp_range_to_range(snapshot, range)
        start_offset = lsp_position_to_offset(snapshot, range[:start])
        end_offset = lsp_position_to_offset(snapshot, range[:end])
        (start_offset...end_offset)
      end

      private def range_to_lsp_range(snapshot, range)
        start = offset_to_lsp_position(snapshot, incl_start(range))
        endpos = offset_to_lsp_position(snapshot, excl_end(range))
        { start: start, end: endpos }
      end

      private def lsp_position_to_offset(snapshot, position)
        snapshot.get_start_offset_for_line(position[:line] + 1) + position[:character]
      end

      private def offset_to_lsp_position(snapshot, offset)
        line = snapshot.get_line_from_offset(offset)
        line_offset = snapshot.get_start_offset_for_line(line)
        { line: line - 1, character: offset - line_offset }
      end
    end
  end
end
