# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Fuzzy snippet picker: the filtered list on top, a preview of the
    # highlighted snippet (statement, description, docs link) below.
    class SnippetView
      PREVIEW_HEIGHT = 8

      def initialize
        @list = ListPane.new
      end

      def render(tui, frame, area, state)
        picker = state.snippets
        list_area, preview_area = tui.layout_split(
          area,
          direction: :vertical,
          constraints: [tui.constraint_fill(1), tui.constraint_length(PREVIEW_HEIGHT)]
        )

        render_list(tui, frame, list_area, picker)
        render_preview(tui, frame, preview_area, state, picker.selected)
      end

      private

      def render_list(tui, frame, area, picker)
        matches = picker.matches
        props = ListPane::Props.new(
          title: " Snippets (#{matches.size}/#{picker.total}) /#{picker.text}█ ",
          items: matches.map(&:label),
          selected: picker.index,
          focused: true
        )
        @list.render(tui, frame, area, props)
      end

      def render_preview(tui, frame, area, state, snippet)
        preview = tui.paragraph(
          text: preview_text(state, snippet),
          wrap: true,
          block: tui.block(
            title: snippet ? " #{snippet.name} " : " Preview ",
            borders: [:all],
            border_style: Theme.inactive_border(tui)
          )
        )

        frame.render_widget(preview, area)
      end

      def preview_text(state, snippet)
        return "No matching snippets" unless snippet

        [snippet.statement(state.keyspace), "", snippet.description, "docs: #{snippet.docs}"].join("\n")
      end
    end
  end
end
