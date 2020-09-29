# typed: true

require "sorbet-runtime"

module Sorbetor
  module Text
    class TextChange < T::Struct
      prop :range, Range
      prop :new_text, String
    end
  end
end
