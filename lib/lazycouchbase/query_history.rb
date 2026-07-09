# frozen_string_literal: true

require "fileutils"
require "json"

module Lazycouchbase
  # The last executed queries with a shell-style recall cursor. Persisted as
  # JSONL in the XDG data directory; a nil path keeps history in memory only.
  class QueryHistory
    LIMIT = 30

    def self.default_path
      base = ENV.fetch("XDG_DATA_HOME") { File.join(Dir.home, ".local", "share") }
      File.join(base, "lazycouchbase", "history.jsonl")
    end

    attr_reader :entries

    def initialize(path = nil)
      @path = path
      @entries = load_entries
      @position = nil
    end

    def record(query)
      reset_position
      return if query.to_s.strip.empty?

      entries << query unless entries.last == query
      entries.shift(entries.size - LIMIT) if entries.size > LIMIT
      save
    end

    # Walks toward older entries and stays on the oldest. Returns nil when
    # there is no history to recall.
    def recall_previous
      return nil if entries.empty?

      @position = @position.nil? ? entries.size - 1 : [@position - 1, 0].max
      entries[@position]
    end

    # Walks toward newer entries; stepping past the newest returns to a blank
    # prompt, like a shell. Returns nil when no recall is in progress.
    def recall_next
      return nil if @position.nil?

      @position += 1
      return entries[@position] if @position < entries.size

      reset_position
      ""
    end

    def reset_position
      @position = nil
    end

    private

    def load_entries
      return [] unless @path && File.file?(@path)

      File.readlines(@path).filter_map do |line|
        value = JSON.parse(line)
        value if value.is_a?(String)
      end.last(LIMIT)
    rescue JSON::ParserError, SystemCallError
      []
    end

    def save
      return unless @path

      FileUtils.mkdir_p(File.dirname(@path))
      File.write(@path, "#{entries.map { |entry| JSON.generate(entry) }.join("\n")}\n")
    rescue SystemCallError
      nil
    end
  end
end
