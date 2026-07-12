# frozen_string_literal: true

require "tmpdir"

RSpec.describe Lazycouchbase::SnippetLibrary do
  def with_toml(content)
    Dir.mktmpdir("lazycouchbase-snippets") do |dir|
      path = File.join(dir, "snippets.toml")
      File.write(path, content)
      yield described_class.new(path: path)
    end
  end

  describe "the bundled library" do
    subject(:library) { described_class.new }

    it "loads every snippet without warnings" do
      expect(library.warnings).to be_empty
      expect(library.snippets.size).to be >= 20
    end

    it "links every snippet to an https docs page" do
      expect(library.snippets.map(&:docs)).to all(start_with("https://"))
    end

    it "keeps templates and examples on a single line for the one-line editor" do
      multiline = library.snippets.select do |snippet|
        snippet.template.include?("\n") || snippet.example.include?("\n")
      end

      expect(multiline).to be_empty
    end

    it "keeps examples concrete — no placeholders left in them" do
      unfinished = library.snippets.select do |snippet|
        snippet.example.match?(/%\{keyspace\}|\bf1\b|\bks2\b|"v1"/)
      end

      expect(unfinished).to be_empty
    end
  end

  describe "malformed data" do
    it "skips entries with missing fields and records a warning" do
      toml = <<~TOML
        [[snippets]]
        name = "Good"
        category = "Basics"
        template = "SELECT 1"
        example = "SELECT 1"
        description = "Fine."
        docs = "https://example.test"

        [[snippets]]
        name = "Bad"
        category = "Basics"
      TOML

      with_toml(toml) do |library|
        expect(library.snippets.map(&:name)).to eq(["Good"])
        expect(library.warnings.first).to include("Skipped snippet 2")
        expect(library.warnings.first).to include("template")
      end
    end

    it "treats blank strings as missing" do
      toml = <<~TOML
        [[snippets]]
        name = "Blank template"
        category = "Basics"
        template = "   "
        example = "SELECT 1"
        description = "Nope."
        docs = "https://example.test"
      TOML

      with_toml(toml) do |library|
        expect(library.snippets).to be_empty
        expect(library.warnings.first).to include("template")
      end
    end

    it "returns no snippets when the file is missing" do
      library = described_class.new(path: "/nonexistent/snippets.toml")

      expect(library.snippets).to be_empty
      expect(library.warnings.first).to include("Snippets unavailable")
    end

    it "survives invalid TOML" do
      with_toml("[[snippets") do |library|
        expect(library.snippets).to be_empty
        expect(library.warnings.first).to include("Snippets unavailable")
      end
    end
  end
end
