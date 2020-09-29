require "test_helper"

class Sorbetor::BaseHostTest < Minitest::Test
  def test_lsp_method_to_ruby_name
    {
      "initialize" => "lsp_initialize",
      "textDocument/didOpen" => "text_document_did_open",
      "textDocument/completion" => "text_document_completion",
      "$/cancel" => "_cancel",
    }.map do |k, v|
      assert_equal v, Sorbetor::LanguageServer::BaseHost.default_lsp_method_to_ruby_name(k)
    end
  end
end
