# typed: true

require "sorbet-runtime"

module Sorbetor
  module Text
    class TextDocument
      extend T::Sig

      attr_reader :filepath, :buffer

      sig { params(filepath: String, buffer: TextBuffer).void }
      def initialize(filepath, buffer)
        @filepath = filepath
        @buffer = buffer
      end

      sig { params(filepath: String).returns(TextDocument) }
      def self.from_path(filepath)
        new(filepath, TextBuffer.new(File.read(filepath)))
      end

      sig { params(filepath: String, content: String).returns(TextDocument) }
      def self.from_s(filepath, content)
        new(filepath, TextBuffer.new(content))
      end

      sig { params(str: String).void }
      def change_filepath(new_file_path)
        @filepath = new_file_path
      end
    end
  end
end
