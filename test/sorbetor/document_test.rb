# typed: true
require "test_helper"

class Sorbetor::DocumentTest < Minitest::Test
  def test_document_comes_back_the_same
    text = "Hello World!"
    document = Sorbetor::Text::TextDocument.from_s("foo.txt", text)
    assert_equal text, document.buffer.current_snapshot.content
  end

  def test_document_can_be_edited
    text = "Hello World!"
    document = Sorbetor::Text::TextDocument.from_s("foo.txt", text)
    buffer = document.buffer
    snapshot = buffer.current_snapshot
    new_snapshot = buffer.apply_changes([
      Sorbetor::Text::TextChange.new(range: (6..10), new_text: "Myself"),
      Sorbetor::Text::TextChange.new(range: (0..4), new_text: "Woot"),
    ])
    refute_same snapshot, buffer.current_snapshot
    assert_same new_snapshot, buffer.current_snapshot
    assert_equal "Woot Myself!", buffer.current_snapshot.content
  end

  def test_document_can_use_lines
    text = "Hello\nWorld\n!"
    document = Sorbetor::Text::TextDocument.from_s("foo.txt", text)
    snapshot = document.buffer.current_snapshot

    assert_equal 1, snapshot.get_line_from_offset(0)
    assert_equal 1, snapshot.get_line_from_offset(3)
    assert_equal 2, snapshot.get_line_from_offset(8)
    assert_equal 2, snapshot.get_line_from_offset(10)
    assert_equal 3, snapshot.get_line_from_offset(12)

    assert_equal 0, snapshot.get_start_offset_for_line(1)
    assert_equal 6, snapshot.get_start_offset_for_line(2)
    assert_equal 12, snapshot.get_start_offset_for_line(3)
  end
end
