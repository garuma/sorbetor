require "sorbet-runtime"

module Sorbetor
  module Utils
    module PropertyBag
      extend T::Sig

      def bag
        @bag ||= {}
      end

      sig { params(String).returns(T.untyped) }
      def get_property(name)
        bag[name]
      end

      def get_or_create_property(name, &value_creator)
        bag.fetch(name) { |k| value_creator.call(k) }
      end
    end
  end
end
