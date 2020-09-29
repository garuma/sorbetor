# frozen_string_literal: true
# typed: true

require "sorbet-runtime"
require "rubocop-ast"

module Sorbetor
  module Parsing
    class ParsedDocument
      extend T::Sig

      PARSED_DOCUMENT_KEY = "parsed_document"

      sig { params(content: String).void }
      def initialize(content)
        @content = content
        @processed_source = RuboCop::AST::ProcessedSource.new(content, 2.7)
      end

      sig { params(snapshot: Sorbetor::Text::TextSnapshot).returns(ParsedDocument) }
      def self.from_snapshot(snapshot)
        snapshot.get_or_create_property(PARSED_DOCUMENT_KEY) do
          ParsedDocument.new(snapshot.content)
        end
      end

      sig { returns(T::Boolean) }
      def valid?
        !!@processed_source.ast
      end

      sig { returns(T::Array[MethodDefinition]) }
      def all_methods
        all_def_nodes.map { |n| MethodDefinition.new(n) }
      end

      sig { params(line: Integer).returns(T.nilable(MethodDefinition)) }
      def get_next_method_definition_at_line(line)
        node = all_def_nodes.find { |n| n.first_line == line + 1 }
        node ? MethodDefinition.new(node) : nil
      end

      sig { returns(T::Array[RuboCop::AST::DefNode]) }
      private def all_def_nodes
        if !valid?
          []
        else
          @all_def_nodes ||= @processed_source.ast.each_descendant(:def).to_a
        end
      end
    end
  end
end
