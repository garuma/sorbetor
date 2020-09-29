require_relative 'lib/sorbetor/version'

Gem::Specification.new do |spec|
  spec.name          = "sorbetor"
  spec.version       = Sorbetor::VERSION
  spec.authors       = ["Jérémie Laval"]
  spec.email         = ["jeremie.laval@gmail.com"]

  spec.summary       = "sorbetor LSP server"
  spec.description   = "Provide an LSP that understands Sorbet sig DSL"
  spec.homepage      = "https://neteril.org"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.3.0")

  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/garuma"
  spec.metadata["changelog_uri"] = "https://github.com/garuma"

  spec.add_development_dependency "debase"
  spec.add_development_dependency "minitest"
  spec.add_development_dependency "rubocop"
  spec.add_development_dependency "ruby-debug-ide"
  spec.add_development_dependency "sorbet"

  spec.add_runtime_dependency "backport"
  spec.add_runtime_dependency "observer"
  spec.add_runtime_dependency "parser"
  spec.add_runtime_dependency "rake", "~> 12.0"
  spec.add_runtime_dependency "rubocop-ast"
  spec.add_runtime_dependency "solargraph"
  spec.add_runtime_dependency "sorbet-runtime"
  spec.add_runtime_dependency "zeitwerk"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
end
