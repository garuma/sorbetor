# typed: true
require "test_helper"

class Sorbetor::StringContainerTest < Minitest::Test
  def test_string_comes_back_the_same
    text = "Hello World!"
    assert_equal Sorbetor::Text::StringContainer.from_s(text).to_s, text
  end

  def test_can_concat_two_strings
    text1 = "Hello "
    text2 = "World!"
    container = Sorbetor::Text::StringContainer.from_s(text1)
    container = container.append(text2)
    assert_equal text1 + text2, container.to_s
  end

  def test_can_remove_string
    text1 = "Hello World!"
    text2 = " World!"
    container = Sorbetor::Text::StringContainer.from_s(text1)
    container = container.remove((0..4))
    assert_equal text2, container.to_s
  end

  def test_can_append_entire_text
    text = "Hello World!"
    container = Sorbetor::Text::StringContainer.empty
    text.each_char { |c| container = container.append(c) }
    assert_equal text, container.to_s
  end

  def test_can_insert_text
    text = "Hello World!"
    container = Sorbetor::Text::StringContainer.from_s(text)
    1.upto(4).each do
      container = container.insert(5, "o")
    end
    assert_equal "Hellooooo World!", container.to_s
  end

  def test_can_replace_beginning
    text = "Hello World!"
    container = Sorbetor::Text::StringContainer.from_s(text).replace((0..4), "Bye")
    assert_equal text.sub("Hello", "Bye"), container.to_s
  end

  def test_can_replace_end
    text = "Hello World!"
    container = Sorbetor::Text::StringContainer.from_s(text).replace((6..10), "Me")
    assert_equal text.sub("World", "Me"), container.to_s
  end

  def test_can_iterate_over_each_chars
    text = "Hello World!"
    result = String.new(capacity: text.length)
    container = Sorbetor::Text::StringContainer.from_s(text)
    container.all_chars.each do |c|
      result.concat(c)
    end
    assert_equal text, result
  end

  def test_can_access_individual_characters
    text = "Hello World!"
    container = Sorbetor::Text::StringContainer.from_s(text)
    assert_equal "H", container[0]
    assert_equal "W", container[6]
    assert_equal "Hello", container[(0...5)]
  end
end
