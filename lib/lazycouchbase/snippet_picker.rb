# frozen_string_literal: true

module Lazycouchbase
  # Transient fuzzy picker over the snippet library, with the same feel as
  # the pane filter: type to narrow, arrows move the highlight, enter
  # commits the highlighted match.
  class SnippetPicker
    attr_reader :text, :index, :warnings

    def initialize(snippets, warnings: [])
      @snippets = snippets
      @warnings = warnings
      reset
    end

    def empty?
      @snippets.empty?
    end

    def total
      @snippets.size
    end

    def reset
      @text = ""
      @index = 0
    end

    def text=(value)
      @text = value || ""
      @index = 0
    end

    def matches
      @snippets.select { |snippet| Fuzzy.match?(@text, snippet.label) }
    end

    def move(delta)
      @index = (@index + delta).clamp(0, [matches.size - 1, 0].max)
    end

    def selected
      matches[@index]
    end
  end
end
