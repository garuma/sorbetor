# typed: true

require "sorbet-runtime"

module Sorbetor
  module Parsing
    class MethodDefinition
      extend T::Sig

      sig { params(def_node: RuboCop::AST::Node).void }
      def initialize(def_node)
        @def_node = def_node
      end

      ##
      # Name of the method itself
      sig { returns(String) }
      def name
        @def_node.method_name&.to_s
      end

      ##
      # An array of String for each parameter that tells their name
      sig { returns(T::Array[String]) }
      def params
        @def_node.arguments.map(&:source)
      end

      sig { returns(T::Boolean) }
      def params?
        @def_node.arguments?
      end

      ##
      # The type we assume would be returned or nil if that cannot be determined
      sig { returns(T.nilable(String)) }
      def returns
        if void?
          "void"
        elsif name.end_with? "?"
          "T::Boolean"
        end
      end

      ##
      # Can we safely assume the method is supposed to return void (e.g. if it's `initialize`)
      sig { returns(T::Boolean) }
      def void?
        @def_node.void_context?
      end
    end
  end
end
