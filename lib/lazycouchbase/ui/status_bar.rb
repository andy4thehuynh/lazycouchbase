# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Single-line footer: connection label and status message on the left,
    # contextual key hints on the right.
    class StatusBar
      # Deliberately terse — the full keymap lives behind ?. The hints only
      # cover moving, getting help, and getting out.
      HINTS = {
        normal: "j/k: move │ ?: help │ q: quit",
        query: "enter: run │ esc: back",
        snippet: "enter: insert │ esc: back",
        document: "j/k: move │ esc: back",
        document_search: "enter: jump │ esc: cancel",
        help: "esc: close",
        filter: "enter: select │ esc: cancel"
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
        parts = [state.connection_label, state.status_message].reject(&:empty?)
        " #{parts.join(" │ ")}"
      end
    end
  end
end
