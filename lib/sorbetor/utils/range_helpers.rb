module Sorbetor
  module Utils
    module RangeHelpers
      module_function

      # Returns the exclusive end index of a range
      def excl_end(range)
        range.max.nil? && range.exclude_end? ? range.last : range.max + 1
      end

      # Returns the inclusive start index of a range
      def incl_start(range)
        range.min.nil? && range.exclude_end? ? range.first : range.min
      end
    end
  end
end
