# typed: true

require "sorbet-runtime"

module Sorbetor
  module Text
    class TextBuffer
      extend T::Sig
      include Utils::PropertyBag
      include Utils::RangeHelpers

      sig { params(str: String).void }
      def initialize(str)
        @snaphot = TextSnapshot.from_s(str)
      end

      sig { returns(TextSnapshot) }
      def current_snapshot
        @snaphot
      end

      sig { params(changes: T::Array[TextChange]).returns(TextSnapshot) }
      def apply_changes(changes)
        container = @snaphot.container
        changes.sort { |c1, c2| incl_start(c2.range) <=> incl_start(c1.range) }.each do |c|
          container = container.replace(c.range, c.new_text)
        end
        new_snaphot = TextSnapshot.new(container)
        @snaphot = new_snaphot
        new_snaphot
      end

      sig { params(range: Range).returns(TextSnapshot) }
      def delete(range)
        replace(range, "")
      end

      sig { params(position: Integer, text: String).returns(TextSnapshot) }
      def insert(position, text)
        replace((position...position), text)
      end

      sig { params(range: Range, new_text: String).returns(TextSnapshot) }
      def replace(range, new_text)
        apply_changes([TextChange.new(range, new_text)])
      end
    end
  end
end
