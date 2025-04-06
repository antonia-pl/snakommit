require_relative 'lib/snakommit/version'

Gem::Specification.new do |spec|
  spec.name          = "snakommit"
  spec.version       = Snakommit::VERSION
  spec.authors       = ["Antonia PL"]
  spec.email         = ["antonia.dev@icloud.com"]

  spec.summary       = "A high-performance, interactive commit manager tool similar to Commitizen"
  spec.description   = "Snakommit helps teams maintain consistent commit message formats by guiding developers through the process of creating standardized commit messages"
  spec.homepage      = "https://github.com/antonia-pl/snakommit"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 3.0.0")

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "bin"
  spec.executables   = ["snakommit", "sk"]
  spec.require_paths = ["lib"]

  spec.add_dependency "tty-prompt", "~> 0.23.1"
  spec.add_dependency "tty-spinner", "~> 0.9.3"
  spec.add_dependency "tty-color", "~> 0.6.0"
  spec.add_dependency "git", "~> 1.12"

  spec.add_development_dependency "bundler", "~> 2.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.10"
  spec.add_development_dependency "rubocop", "~> 1.25.1"
  spec.add_development_dependency "parallel", "~> 1.21"
end 