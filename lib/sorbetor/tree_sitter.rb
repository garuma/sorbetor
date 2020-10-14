# frozen_string_literal: true

require "ffi"

# rubocop:disable Style/SymbolArray
module Sorbetor
  module TreeSitter
    module MethodAttacher
      def attach_method(a_module, name, prefix)
        ruby_name = name.to_s[prefix.length..].to_sym
        define_method(ruby_name) do |*args, &block|
          args.prepend(self)
          a_module.public_send(name, *args, &block)
        end
        # puts "defined #{ruby_name} from #{name} and #{prefix} in #{self}"
      end

      def attach_all_methods(a_module, prefix)
        a_module.singleton_methods.each do |method|
          method_str = method.to_s
          if method_str.start_with?(prefix) && !method_str.end_with?("_new", "_delete")
            attach_method(a_module, method, prefix)
          end
        end
      end
    end

    extend FFI::Library

    ffi_lib "tree-sitter"

    class Point < FFI::Struct
      layout :row, :uint32,
             :column, :uint32
    end

    class Range < FFI::Struct
      layout :start_point, Point,
             :end_point, Point,
             :start_byte, :uint32,
             :end_byte, :uint32
    end

    InputEncoding = enum(:utf8, :utf16)
    SymbolType = enum(:regular, :anonymous, :auxiliary)

    # const char *(*read)(void *payload, uint32_t byte_index, Point position, uint32_t *bytes_read);
    callback :input_read, [:pointer, :uint32, Point.by_ref, :pointer], :buffer_in

    class Input < FFI::Struct
      layout :payload, :pointer,
             :read, :input_read,
             :encoding, InputEncoding
    end

    LogType = enum(:parse, :lex)

    callback :log_func, [:pointer, LogType, :string], :void

    class Logger < FFI::Struct
      layout :payload, :pointer,
             :log, :log_func
    end

    class Tree < FFI::AutoPointer
      def self.release(ptr)
        TreeSitter.ts_tree_delete(ptr)
      end
    end

    class Node < FFI::Struct
      layout :context, [:uint32, 4],
             :id, :pointer,
             :tree, Tree
    end

    class InputEdit < FFI::Struct
      layout :start_byte, :uint32,
             :old_end_byte, :uint32,
             :new_end_byte, :uint32,
             :start_point, Point,
             :old_end_point, Point,
             :new_end_point, Point
    end

    class QueryCapture < FFI::Struct
      layout :node, Node,
             :index, :uint32
    end

    class QueryMatch < FFI::Struct
      layout :id, :uint32,
             :pattern_index, :uint16,
             :capture_count, :uint16,
             :captures, QueryCapture.ptr
    end

    QueryError = enum(:none, :syntax, :node_type, :field, :capture, :structure)

    typedef :uint16, :ts_symbol
    typedef :uint16_t, :field_id

    class Parser < FFI::AutoPointer
      def self.release(ptr)
        TreeSitter.ts_parser_delete(ptr)
      end
    end

    typedef :pointer, :language

    class Query < FFI::AutoPointer
      def self.release(ptr)
        TreeSitter.ts_query_delete(ptr)
      end
    end

    class QueryCursor < FFI::AutoPointer
      def self.release(ptr)
        TreeSitter.ts_query_cursor_delete(ptr)
      end
    end

    class Language < FFI::AutoPointer
      def self.release(ptr)
        # Do nothing, we should never free a language
      end
    end

    module RubyBinding
      extend FFI::Library

      ffi_lib "tree-sitter-ruby"

      attach_function :tree_sitter_ruby, [], Language
    end

    module LibStdout
      extend FFI::Library

      ffi_lib "stdio"

      attach_function :stdio_get_output_stream, [], :pointer
    end

    ## Parser

    # TSParser *ts_parser_new(void);
    attach_function :ts_parser_new, [], Parser
    # void ts_parser_delete(TSParser *parser);
    attach_function :ts_parser_delete, [Parser], :void
    # bool ts_parser_set_language(TSParser *self, const TSLanguage *language);
    attach_function :ts_parser_set_language, [Parser, :language], :bool
    # const TSLanguage *ts_parser_language(const TSParser *self);
    attach_function :ts_parser_language, [Parser], Language
    # bool ts_parser_set_included_ranges(TSParser *self, const TSRange *ranges, uint32_t length);
    attach_function :ts_parser_set_included_ranges, [Parser, :pointer, :uint32], :bool
    # const TSRange *ts_parser_included_ranges(const TSParser *self, uint32_t *length);
    attach_function :ts_parser_included_ranges, [Parser, :uint32], Range.ptr
    # void ts_parser_reset(TSParser *self);
    attach_function :ts_parser_reset, [Parser], :void
    # void ts_parser_set_timeout_micros(TSParser *self, uint64_t timeout);
    attach_function :ts_parser_set_timeout_micros, [Parser, :uint64_t], :void
    # uint64_t ts_parser_timeout_micros(const TSParser *self);
    attach_function :ts_parser_timeout_micros, [Parser], :uint64_t
    # void ts_parser_set_cancellation_flag(TSParser *self, const size_t *flag);
    attach_function :ts_parser_set_cancellation_flag, [Parser, :size_t], :void
    # const size_t *ts_parser_cancellation_flag(const TSParser *self);
    attach_function :ts_parser_cancellation_flag, [Parser], :size_t
    # void ts_parser_set_logger(TSParser *self, TSLogger logger);
    attach_function :ts_parser_set_logger, [Parser, Logger.by_value], :void
    # TSLogger ts_parser_logger(const TSParser *self);
    attach_function :ts_parser_logger, [Parser], Logger
    # TSTree *ts_parser_parse_string(TSParser *self, const TSTree *old_tree, const char *string, uint32_t length);
    attach_function :ts_parser_parse_string, [Parser, Tree, :string, :uint32], Tree
    # TSTree *ts_parser_parse(TSParser *self, const TSTree *old_tree, Input input);
    attach_function :ts_parser_parse, [Parser, Tree, Input.by_value], Tree
    # TSTree *ts_parser_parse_string_encoding(TSParser *self, const TSTree *old_tree, const char *string, uint32_t length, TSInputEncoding encoding);
    attach_function :ts_parser_parse_string_encoding, [Parser, Tree, :string, :uint32, InputEncoding], Tree
    # void ts_parser_print_dot_graphs(TSParser *self, int file);
    attach_function :ts_parser_print_dot_graphs, [Parser, :int], :void

    ## Tree

    # Node ts_tree_root_node(const TSTree *self);
    attach_function :ts_tree_root_node, [Tree], Node
    # void ts_tree_delete(TSTree *self);
    attach_function :ts_tree_delete, [Tree], :void
    # void ts_tree_edit(TSTree *self, const InputEdit *edit);
    attach_function :ts_tree_edit, [Tree, InputEdit.by_ref], :void
    # void ts_tree_print_dot_graph(const TSTree *, FILE *);
    attach_function :ts_tree_print_dot_graph, [Tree, :pointer], :void

    ## Query

    # TSQuery *ts_query_new(const TSLanguage *language, const char *source, uint32_t source_len, uint32_t *error_offset, TSQueryError *error_type);
    attach_function :ts_query_new, [:language, :string, :uint32, :pointer, :pointer], Query
    # void ts_query_delete(TSQuery *);
    attach_function :ts_query_delete, [Query], :void
    # uint32_t ts_query_pattern_count(const TSQuery *);
    attach_function :ts_query_pattern_count, [Query], :uint32
    # uint32_t ts_query_capture_count(const TSQuery *);
    attach_function :ts_query_capture_count, [Query], :uint32
    # uint32_t ts_query_string_count(const TSQuery *);
    attach_function :ts_query_string_count, [Query], :uint32
    # uint32_t ts_query_start_byte_for_pattern(const TSQuery *, uint32_t);
    attach_function :ts_query_start_byte_for_pattern, [Query, :uint32], :uint32
    # bool ts_query_step_is_definite(const TSQuery *self, uint32_t byte_offset);
    attach_function :ts_query_step_is_definite, [Query, :uint32], :bool
    # const char *ts_query_capture_name_for_id(const TSQuery *, uint32_t id, uint32_t *length);
    attach_function :ts_query_capture_name_for_id, [Query, :uint32, :uint32], :string
    # const char *ts_query_string_value_for_id(const TSQuery *, uint32_t id, uint32_t *length);
    attach_function :ts_query_string_value_for_id, [Query, :uint32, :uint32], :string
    # void ts_query_disable_capture(TSQuery *, const char *, uint32_t);
    attach_function :ts_query_disable_capture, [Query, :string, :uint32], :void
    # void ts_query_disable_pattern(TSQuery *, uint32_t);
    attach_function :ts_query_disable_pattern, [Query, :uint32], :void

    ## QueryCursor

    # TSQueryCursor *ts_query_cursor_new(void);
    attach_function :ts_query_cursor_new, [], QueryCursor
    # void ts_query_cursor_delete(TSQueryCursor *);
    attach_function :ts_query_cursor_delete, [QueryCursor], :void
    # void ts_query_cursor_exec(TSQueryCursor *, const TSQuery *, Node);
    attach_function :ts_query_cursor_exec, [QueryCursor, Query, Node.by_value], :void
    # bool ts_query_cursor_next_match(TSQueryCursor *, TSQueryMatch *match);
    attach_function :ts_query_cursor_next_match, [QueryCursor, QueryMatch.by_ref], :bool
    # void ts_query_cursor_remove_match(TSQueryCursor *, uint32_t id);
    attach_function :ts_query_cursor_remove_match, [Query, :uint32], :void
    # bool ts_query_cursor_next_capture(TSQueryCursor *, TSQueryMatch *match, uint32_t *capture_index);
    attach_function :ts_query_cursor_next_capture, [QueryCursor, QueryMatch.by_ref, :pointer], :bool
    # void ts_query_cursor_set_byte_range(TSQueryCursor *, uint32_t, uint32_t);
    attach_function :ts_query_cursor_set_byte_range, [Query, :uint32, :uint32], :void
    # void ts_query_cursor_set_point_range(TSQueryCursor *, TSPoint, TSPoint);
    attach_function :ts_query_cursor_set_point_range, [Query, Point.by_value, Point.by_value], :void

    ## Node

    # const char *ts_node_type(Node);
    attach_function :ts_node_type, [Node.by_value], :string
    # TSSymbol ts_node_symbol(Node);
    attach_function :ts_node_symbol, [Node.by_value], :ts_symbol
    # uint32_t ts_node_start_byte(Node);
    attach_function :ts_node_start_byte, [Node.by_value], :uint32
    # Point ts_node_start_point(Node);
    attach_function :ts_node_start_point, [Node.by_value], Point
    # uint32_t ts_node_end_byte(Node);
    attach_function :ts_node_end_byte, [Node.by_value], :uint32
    # Point ts_node_end_point(Node);
    attach_function :ts_node_end_point, [Node.by_value], Point
    # bool ts_node_eq(Node, Node);
    attach_function :ts_node_eq, [Node.by_value, Node.by_value], :bool
    # char *ts_node_string(Node);
    attach_function :ts_node_string, [Node.by_value], :string
    # bool ts_node_is_null(Node);
    attach_function :ts_node_is_null, [Node.by_value], :bool
    # bool ts_node_is_named(Node);
    attach_function :ts_node_is_named, [Node.by_value], :bool
    # bool ts_node_is_missing(Node);
    attach_function :ts_node_is_missing, [Node.by_value], :bool
    # bool ts_node_is_extra(Node);
    attach_function :ts_node_is_extra, [Node.by_value], :bool
    # bool ts_node_has_changes(Node);
    attach_function :ts_node_has_changes, [Node.by_value], :bool
    # bool ts_node_has_error(Node);
    attach_function :ts_node_has_error, [Node.by_value], :bool
    # Node ts_node_parent(Node);
    attach_function :ts_node_parent, [Node.by_value], Node
    # Node ts_node_child(Node, uint32_t);
    attach_function :ts_node_child, [Node.by_value, :uint32], Node
    # uint32_t ts_node_child_count(Node);
    attach_function :ts_node_child_count, [Node.by_value], :uint32
    # Node ts_node_named_child(Node, uint32_t);
    attach_function :ts_node_named_child, [Node.by_value, :uint32], Node
    # uint32_t ts_node_named_child_count(Node);
    attach_function :ts_node_named_child_count, [Node.by_value], :uint32
    # Node ts_node_child_by_field_name(Node self, const char *field_name,  uint32_t field_name_length);
    attach_function :ts_node_child_by_field_name, [Node.by_value, :string, :uint32], Node
    # Node ts_node_child_by_field_id(Node, TSFieldId);
    attach_function :ts_node_child_by_field_id, [Node, :field_id], Node
    # Node ts_node_next_sibling(Node);
    attach_function :ts_node_next_sibling, [Node.by_value], Node
    # Node ts_node_prev_sibling(Node);
    attach_function :ts_node_prev_sibling, [Node.by_value], Node
    # Node ts_node_next_named_sibling(Node);
    attach_function :ts_node_next_named_sibling, [Node.by_value], Node
    # Node ts_node_prev_named_sibling(Node);
    attach_function :ts_node_prev_named_sibling, [Node.by_value], Node
    # Node ts_node_first_child_for_byte(Node, uint32_t);
    attach_function :ts_node_first_child_for_byte, [Node.by_value, :uint32], Node
    # Node ts_node_first_named_child_for_byte(Node, uint32_t);
    attach_function :ts_node_first_named_child_for_byte, [Node.by_value, :uint32], Node
    # Node ts_node_descendant_for_byte_range(Node, uint32_t, uint32_t);
    attach_function :ts_node_descendant_for_byte_range, [Node.by_value, :uint32, :uint32], Node
    # Node ts_node_descendant_for_point_range(Node, Point, Point);
    attach_function :ts_node_descendant_for_point_range, [Node.by_value, Point.by_value, Point.by_value], Node
    # Node ts_node_named_descendant_for_byte_range(Node, uint32_t, uint32_t);
    attach_function :ts_node_named_descendant_for_byte_range, [Node.by_value, :uint32, :uint32], Node
    # Node ts_node_named_descendant_for_point_range(Node, Point, Point);
    attach_function :ts_node_named_descendant_for_point_range, [Node.by_value, Point.by_value, Point.by_value], Node

    ## Language

    # uint32_t ts_language_symbol_count(const TSLanguage *);
    attach_function :ts_language_symbol_count, [Language], :uint32
    # const char *ts_language_symbol_name(const TSLanguage *, TSSymbol);
    attach_function :ts_language_symbol_name, [Language, :ts_symbol], :string
    # TSSymbol ts_language_symbol_for_name(const TSLanguage *self, const char *string, uint32_t length, bool is_named);
    attach_function :ts_language_symbol_for_name, [Language, :string, :uint32, :bool], :ts_symbol
    # uint32_t ts_language_field_count(const TSLanguage *);
    attach_function :ts_language_field_count, [Language], :uint32
    # const char *ts_language_field_name_for_id(const TSLanguage *, TSFieldId);
    attach_function :ts_language_field_name_for_id, [Language, :field_id], :string
    # TSFieldId ts_language_field_id_for_name(const TSLanguage *, const char *, uint32_t);
    attach_function :ts_language_field_id_for_name, [Language, :string, :uint32], :field_id
    # TSSymbolType ts_language_symbol_type(const TSLanguage *, TSSymbol);
    attach_function :ts_language_symbol_type, [Language, :ts_symbol], SymbolType
    # uint32_t ts_language_version(const TSLanguage *);
    attach_function :ts_language_version, [Language], :uint32

    class Node
      extend Sorbetor::TreeSitter::MethodAttacher
      attach_all_methods TreeSitter, "ts_node_"
    end

    class Tree
      extend Sorbetor::TreeSitter::MethodAttacher
      attach_all_methods TreeSitter, "ts_tree_"
    end

    class Parser
      extend Sorbetor::TreeSitter::MethodAttacher
      attach_all_methods TreeSitter, "ts_parser_"

      def self.new_ruby_parser
        parser = TreeSitter.ts_parser_new
        ruby_language = TreeSitter::RubyBinding.tree_sitter_ruby
        parser.set_language(ruby_language)
        # TreeSitter.ts_parser_set_language(parser, ruby_language)
        parser
      end

      def timeout_micros=(...)
        set_timeout_micros(...)
      end

      def cancellation_flag=(...)
        set_cancellation_flag(...)
      end

      def logger=(...)
        set_logger(...)
      end
    end

    class Query
      extend Sorbetor::TreeSitter::MethodAttacher
      attach_all_methods TreeSitter, "ts_query_"
    end

    class QueryCursor
      extend Sorbetor::TreeSitter::MethodAttacher
      attach_all_methods TreeSitter, "ts_query_cursor_"
    end

    class Language
      extend Sorbetor::TreeSitter::MethodAttacher
      attach_all_methods TreeSitter, "ts_language_"
    end
  end
  # rubocop:enable Style/SymbolArray
end
