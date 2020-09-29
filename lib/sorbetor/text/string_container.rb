# Inspired from Microsoft.VisualStudio.Text.Implementation.StringRebuilder
require "sorbet-runtime"

module Sorbetor
  module Text
    class StringContainer
      extend T::Sig
      include Sorbetor::Utils::RangeHelpers

      sig { params(node: BaseNode).void }
      def initialize(node)
        @root = node
        freeze
      end

      sig { params(str: String).returns(StringContainer) }
      def self.from_s(str)
        new(StringNode.new(str))
      end

      sig { returns(StringContainer) }
      def self.empty
        @@empty ||= from_s("")
      end

      def [](key)
        if key.is_a?(Integer)
          @root.get_text((key...key + 1))
        elsif key.is_a?(Range)
          @root.get_text(key)
        end
      end

      sig { returns(Enumerator) }
      def all_chars
        @root.all_chars
      end

      sig { returns(Integer) }
      def length
        @root.length
      end

      sig { params(range: Range).returns(StringContainer) }
      def remove(range)
        new_node = @root.assemble((0...incl_start(range)), (excl_end(range)...length))
        StringContainer.new(new_node)
      end

      sig { params(position: Integer, new_text: String).returns(StringContainer) }
      def insert(position, new_text)
        replace((position...position), new_text)
      end

      sig { params(range: Range, new_text: String).returns(StringContainer) }
      def replace(range, new_text)
        return remove(range) if new_text.empty?

        new_node = @root.assemble_n((0...incl_start(range)), StringNode.new(new_text), (excl_end(range)...length))
        StringContainer.new(new_node)
      end

      sig { params(new_text: String).returns(StringContainer) }
      def append(new_text)
        insert(@root.length, new_text)
      end

      sig { returns(String) }
      def to_s
        @root.to_s
      end
    end

    # Basically define a binary tree that can be rebalanced by combining nodes together
    class BaseNode
      extend T::Sig
      include Sorbetor::Utils::RangeHelpers

      attr_reader :depth, :length

      sig { void }
      def initialize
        @depth = 0
        @length = 0
      end

      sig { params(left: Range, right: Range).returns(BaseNode) }
      def assemble(left, right)
        if left.count.zero?
          slice(right)
        elsif right.count.zero?
          slice(left)
        else
          BinaryNode.new(slice(left), slice(right))
        end
      end

      sig { returns(T::Boolean) }
      def empty?
        @length == 0
      end

      sig { params(left: Range, node: BaseNode, right: Range).returns(BaseNode) }
      def assemble_n(left, node, right)
        if node.empty?
          assemble(left, right)
        elsif left.count == 0 && right.count == 0
          node
        elsif left.count == 0
          BinaryNode.new(node, slice(right))
        elsif right.count == 0
          BinaryNode.new(slice(left), node)
        else
          BinaryNode.new(slice(left), BinaryNode.new(node, slice(right)))
        end
      end

      sig { returns(String) }
      def to_s
        get_text((0...@length))
      end
    end

    class StringNode < BaseNode
      sig { params(str: String, range: Range).void }
      def initialize(str, range = nil)
        super()
        @str = str
        @depth = 0
        @range = range.nil? ? (0...str.length) : range
        @length = @range.count
        freeze
      end

      def self.empty
        @@empty ||= new("")
      end

      sig { params(range: T.any(Range, Integer)).returns(String) }
      def get_text(range)
        final_range = (incl_start(@range) + incl_start(range)...incl_start(@range) + excl_end(range))
        @str[final_range]
      end

      sig { returns(Enumerator) }
      def all_chars
        @str.each_char.lazy.drop(@range.min).take(@range.count)
      end

      sig { params(range: Range).returns(StringNode) }
      def slice(range)
        if range.count.zero?
          empty
        elsif range == @range
          self
        else
          final_range = (incl_start(@range) + incl_start(range)...incl_start(@range) + excl_end(range))
          StringNode.new(@str, final_range)
        end
      end
    end

    class BinaryNode < BaseNode
      MAX_CHARACTERS_TO_CONSOLIDATE = 200

      sig { params(left_node: BaseNode, right_node: BaseNode).void }
      def initialize(left_node, right_node)
        super()
        @left_node = left_node
        @right_node = right_node
        @depth = 1 + [left_node.depth, right_node.depth].max
        @length = left_node.length + right_node.length
        freeze
      end

      sig { params(range: Range).returns(String) }
      def get_text(range)
        if excl_end(range) <= @left_node.length
          @left_node.get_text(range)
        elsif incl_start(range) >= @left_node.length
          @right_node.get_text((incl_start(range) - @left_node.length...excl_end(range) - @left_node.length))
        else
          lrange = (incl_start(range)...@left_node.length)
          left_text = @left_node.get_text(lrange)

          rrange = (0...excl_end(range) - lrange.count)
          right_text = @right_node.get_text(rrange)

          left_text + right_text
        end
      end

      sig { returns(Enumerator) }
      def all_chars
        @left_node.all_chars.chain(@right_node.all_chars)
      end

      sig { params(range: Range).returns(BaseNode) }
      def slice(range)
        if excl_end(range) <= @left_node.length
          @left_node.slice(range)
        elsif incl_start(range) >= @left_node.length
          @right_node.slice((incl_start(range) - @left_node.length...excl_end(range) - @left_node.length))
        else
          BinaryNode.new(
            @left_node.slice((incl_start(range)...@left_node.length)),
            @right_node.slice((0...excl_end(range) - @left_node.length))
          )
        end
      end
    end
  end
end
