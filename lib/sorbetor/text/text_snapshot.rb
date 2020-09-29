# typed: true

require "sorbet-runtime"

module Sorbetor
  module Text
    class TextSnapshot
      extend T::Sig
      include Utils::PropertyBag

      attr_reader :container

      sig { params(container: StringContainer).void }
      def initialize(container)
        @container = container
      end

      def self.from_s(content)
        new(StringContainer.from_s(content))
      end

      def length
        @container.length
      end

      def content
        @container.to_s
      end

      def get_line_from_offset(offset)
        newlines_mappings.reverse_each.with_index do |newline_offset, index|
          return newlines_mappings.length - index if offset > newline_offset
        end
      end

      def get_start_offset_for_line(line)
        newlines_mappings[line - 1] + 1 if line >= 1 && line <= newlines_mappings.length
      end

      private def newlines_mappings
        @newlines_mappings ||= @container.all_chars.each.with_index.filter_map { |c, pos| pos if c == "\n" }.to_a.prepend(-1)
      end
    end
  end
end
