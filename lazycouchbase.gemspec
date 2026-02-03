# frozen_string_literal: true

require_relative "lib/lazycouchbase/version"

Gem::Specification.new do |spec|
  spec.name = "lazycouchbase"
  spec.version = Lazycouchbase::VERSION
  spec.authors = ["Andy Huynh"]
  spec.email = ["2831414+andy4thehuynh@users.noreply.github.com"]

  spec.summary = ""
  spec.description = ""
  spec.homepage = ""
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["allowed_push_host"] = ""

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/andy4thehuynh/lazycouchbase"
  spec.metadata["changelog_uri"] = ""

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "couchbase", "~> 3.7"
  spec.add_dependency "ratatui_ruby", "~> 1.0"
  spec.add_dependency "toml-rb", "~> 3.0"
  spec.add_dependency "zeitwerk", "~> 2.6"
end
