require "test_helper"

class Sorbetor::ParsedDocumentTest < Minitest::Test
  def test_can_find_all_methods
    parsed_doc = Sorbetor::Parsing::ParsedDocument.new("
      class FooBar
        def blabla_noarg
        end

        def blabla_onearg(arg)
        end
      end")

    assert parsed_doc.valid?
    defs = parsed_doc.all_methods
    assert_equal 2, defs.length
    assert_equal(%w[blabla_noarg blabla_onearg], parsed_doc.all_methods.map(&:name))
  end

  def test_can_find_corresponding_method
    parsed_doc = Sorbetor::Parsing::ParsedDocument.new("
      class FooBar
        sig { }
        def blabla_noarg
        end

        sig { }
        def blabla_onearg(arg)
        end

        sig { }
        def initialize(foo, bar)
        end

        sig { }
        def valid?
        end
      end")

    assert parsed_doc.valid?
    method1 = parsed_doc.get_next_method_definition_at_line(3)
    method2 = parsed_doc.get_next_method_definition_at_line(7)
    method3 = parsed_doc.get_next_method_definition_at_line(11)
    method4 = parsed_doc.get_next_method_definition_at_line(15)

    assert_equal "blabla_noarg", method1.name
    assert_equal "blabla_onearg", method2.name
    assert_equal "initialize", method3.name
    assert_equal "valid?", method4.name

    assert_equal ["arg"], method2.params
    assert !method1.params?
    assert_equal %w[foo bar], method3.params
    assert !method4.params?

    assert !method1.void?
    assert !method2.void?
    assert method3.void?
    assert_nil method1.returns
    assert_nil method2.returns
    assert_equal "void", method3.returns
    assert_equal "T::Boolean", method4.returns
  end
end
