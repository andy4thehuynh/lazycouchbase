# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Single-line footer: status message on the left, contextual key hints
    # and the connection label on the right.
    class StatusBar
      HINTS = {
        normal: "j/k: move │ enter: open │ /: filter │ :: query │ ?: help │ q: quit",
        query: "enter: run │ esc: back",
        document: "j/k: move │ /: search │ t: keys │ y/Y: yank │ esc: back",
        document_search: "type to search │ enter: jump │ esc: cancel",
        help: "esc: close",
        filter: "type to narrow │ ↑/↓: move │ enter: select │ esc: cancel"
      }.freeze

      def render(tui, frame, area, state)
        hints_text = HINTS.fetch(state.mode)
        message_area, hints_area = tui.layout_split(
          area,
          direction: :horizontal,
          constraints: [tui.constraint_fill(1), tui.constraint_length(hints_text.length + 1)]
        )

        message = tui.paragraph(text: left_side(state), style: Theme.status(tui, state.status_kind))
        hints = tui.paragraph(text: hints_text, style: Theme.hint(tui), alignment: :right)

        frame.render_widget(message, message_area)
        frame.render_widget(hints, hints_area)
      end

      private

      def left_side(state)
        return document_breadcrumb(state) if %i[document document_search].include?(state.mode)
        return " #{state.status_message}" if state.connection_label.empty?

        " #{state.connection_label} │ #{state.status_message}"
      end

      # Where the cursor is, not where the connection points: the document
      # modes trade the connection label for orientation.
      def document_breadcrumb(state)
        parts = [state.selected_bucket, state.selected_collection, state.doc.id]
        parts << state.doc.path unless state.doc.path.empty?
        crumb = parts.compact.map(&:to_s).join(" › ")
        return " #{crumb}" if state.status_message.empty?

        " #{crumb} │ #{state.status_message}"
      end
    end
  end
end
