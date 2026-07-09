# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Full-pane view of a single document: soft-wrapped pretty JSON with a
    # cursor line, an inline search prompt in the title, and a keys-only
    # outline the cursor can jump through.
    class DocumentView
      def initialize
        @outline_pane = ListPane.new
      end

      def render(tui, frame, area, state)
        doc = state.doc
        doc.view_height = [area.height - 2, 1].max
        doc.view_width = [area.width - 2, 1].max

        if doc.outline?
          render_outline(tui, frame, area, doc)
        else
          render_lines(tui, frame, area, state, doc)
        end
      end

      private

      def render_lines(tui, frame, area, state, doc)
        visible = doc.visual_lines[doc.scroll, doc.view_height] || []
        lines = visible.each_with_index.map do |line, offset|
          style = doc.scroll + offset == doc.cursor ? Theme.highlight(tui) : nil
          tui.line(spans: [tui.span(content: line.text, style: style)])
        end

        paragraph = tui.paragraph(text: lines, block: block(tui, title(state, doc)))
        frame.render_widget(paragraph, area)
      end

      def render_outline(tui, frame, area, doc)
        props = ListPane::Props.new(
          title: " Keys: #{doc.id} (#{doc.outline_entries.size}) ",
          items: doc.outline_entries.map(&:text),
          selected: doc.outline_index,
          focused: true
        )
        @outline_pane.render(tui, frame, area, props)
      end

      def title(state, doc)
        return " Document: #{doc.id} — /#{doc.search_text}█ " if state.mode == :document_search

        " Document: #{doc.id} "
      end

      def block(tui, title)
        tui.block(title: title, borders: [:all], border_style: Theme.active_border(tui))
      end
    end
  end
end
