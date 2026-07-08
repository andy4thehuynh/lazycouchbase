# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Single-line footer: status message on the left, contextual key hints
    # and the connection label on the right.
    class StatusBar
      HINTS = {
        normal: "j/k: move │ enter: open │ :: query │ ?: help │ q: quit",
        query: "enter: run │ esc: back",
        document: "j/k: scroll │ esc: back",
        help: "esc: close"
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
        return " #{state.status_message}" if state.connection_label.empty?

        " #{state.connection_label} │ #{state.status_message}"
      end
    end
  end
end
