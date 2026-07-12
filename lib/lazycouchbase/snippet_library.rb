# frozen_string_literal: true

require "toml-rb"

module Lazycouchbase
  # Loads the bundled SQL++ snippets from data/snippets.toml. Malformed
  # entries are skipped with a warning instead of raising: the snippet
  # picker is a convenience and must never take the app down at startup.
  class SnippetLibrary
    REQUIRED = %w[name category template description docs].freeze

    def self.default_path
      File.expand_path("../../data/snippets.toml", __dir__)
    end

    attr_reader :snippets, :warnings

    def initialize(path: self.class.default_path)
      @snippets = []
      @warnings = []
      load_file(path)
    end

    private

    def load_file(path)
      data = TomlRB.load_file(path)
      Array(data["snippets"]).each_with_index do |entry, index|
        snippet = build(entry, index)
        @snippets << snippet if snippet
      end
    rescue SystemCallError, TomlRB::ParseError => e
      @warnings << "Snippets unavailable: #{e.message}"
    end

    def build(entry, index)
      missing = missing_fields(entry)
      return Snippet.new(**entry.slice(*REQUIRED).transform_keys(&:to_sym)) if missing.empty?

      @warnings << "Skipped snippet #{index + 1} (missing #{missing.join(", ")})"
      nil
    end

    def missing_fields(entry)
      return REQUIRED unless entry.is_a?(Hash)

      REQUIRED.reject { |field| entry[field].is_a?(String) && !entry[field].strip.empty? }
    end
  end
end
