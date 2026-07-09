# frozen_string_literal: true

require "json"

module Lazycouchbase
  # Everything the document view tracks: the annotated lines of the open
  # document, the soft-wrapped visual lines for the current pane width, a
  # cursor the scroll follows, the line search, and the keys-only outline.
  # Pure state -- it knows nothing about Couchbase or the terminal.
  class DocumentState
    VisualLine = Data.define(:text, :logical)

    attr_reader :id, :cursor, :scroll, :view_height, :view_width,
                :search_text, :outline_index

    def initialize
      @id = nil
      @lines = []
      @outline = []
      @view_height = 0
      @view_width = 0
      reset_view
    end

    def load(id, content)
      @id = id
      @lines, @outline = build_lines(content)
      reset_view
    end

    def body
      @lines.map(&:text).join("\n")
    end

    def view_height=(value)
      @view_height = [value, 1].max
      follow_cursor
    end

    def view_width=(value)
      value = [value, 1].max
      return if value == @view_width

      @view_width = value
      @visual_lines = nil
      place_cursor(@cursor)
    end

    def visual_lines
      @visual_lines ||= @lines.each_with_index.flat_map do |line, logical|
        SoftWrap.wrap(line.text, @view_width).map { |text| VisualLine.new(text: text, logical: logical) }
      end
    end

    def line_count
      visual_lines.size
    end

    def move_cursor(delta)
      place_cursor(@cursor + delta)
    end

    def cursor_edge(edge)
      place_cursor(edge == :first ? 0 : line_count - 1)
    end

    def path
      current_line&.path.to_s
    end

    # [label, text] for the clipboard: strings raw, containers pretty-printed.
    def yank_value
      line = current_line
      return nil unless line

      [line.path.to_s, value_text(line)]
    end

    def start_search
      @search_text = ""
      @search_origin = @cursor
    end

    def search_text=(value)
      @search_text = value || ""
      target = @search_text.empty? ? @search_origin : search_matches.first
      place_cursor(target || @search_origin)
    end

    def cancel_search
      place_cursor(@search_origin)
      @search_text = ""
    end

    def next_match(direction)
      matches = @search_text.empty? ? [] : search_matches
      return if matches.empty?

      place_cursor(nearest_match(matches, direction))
    end

    def outline?
      @outline_view
    end

    def outline_entries
      @outline
    end

    def outline_available?
      @outline.any?
    end

    def toggle_outline
      return unless outline_available?

      @outline_view = !@outline_view
      @outline_index = 0 if @outline_view
    end

    def move_outline_selection(delta)
      @outline_index = (@outline_index + delta).clamp(0, [@outline.size - 1, 0].max)
    end

    def commit_outline_selection
      entry = @outline[@outline_index]
      @outline_view = false
      return unless entry

      target = visual_lines.index { |line| line.logical == entry.line }
      place_cursor(target) if target
    end

    private

    def reset_view
      @cursor = 0
      @scroll = 0
      @visual_lines = nil
      @search_text = ""
      @search_origin = 0
      @outline_view = false
      @outline_index = 0
    end

    def build_lines(content)
      return [text_lines(content.to_s), []] unless content.is_a?(Hash) || content.is_a?(Array)

      document = JsonDocument.new(content)
      [document.lines, document.outline]
    rescue StandardError
      [text_lines(content.inspect), []]
    end

    def text_lines(text)
      text.split("\n").map { |line| JsonDocument::Line.new(text: line, path: "", node: nil, key: nil) }
    end

    def current_line
      visual = visual_lines[@cursor]
      visual && @lines[visual.logical]
    end

    def value_text(line)
      node = line.node
      return line.text.strip if node.nil?
      return node if node.is_a?(String)

      node.is_a?(Hash) || node.is_a?(Array) ? JSON.pretty_generate(node) : node.to_json
    end

    def search_matches
      visual_lines.each_index.select { |index| Fuzzy.match?(@search_text, visual_lines[index].text) }
    end

    def nearest_match(matches, direction)
      if direction.positive?
        matches.find { |index| index > @cursor } || matches.first
      else
        matches.reverse.find { |index| index < @cursor } || matches.last
      end
    end

    def place_cursor(value)
      @cursor = value.clamp(0, [line_count - 1, 0].max)
      follow_cursor
    end

    def follow_cursor
      height = @view_height.positive? ? @view_height : 1
      @scroll = @cursor if @cursor < @scroll
      @scroll = @cursor - height + 1 if @cursor >= @scroll + height
      @scroll = @scroll.clamp(0, [line_count - height, 0].max)
    end
  end
end
