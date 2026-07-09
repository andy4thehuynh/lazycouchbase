# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Full-pane, scrollable view of a single document's pretty-printed JSON.
    class DocumentView
      def render(tui, frame, area, state)
        # Lets the scroll clamp stop at the last page instead of the last line.
        state.document_view_height = [area.height - 2, 1].max

        # ratatui_ruby's wrap always trims leading whitespace, which flattens
        # the JSON indentation; clipping the rare over-long line is the
        # lesser evil. Unwrapped lines also keep the scroll clamp exact.
        paragraph = tui.paragraph(
          text: state.document_body,
          wrap: false,
          scroll: [state.document_scroll, 0],
          block: tui.block(
            title: " Document: #{state.document_id} ",
            borders: [:all],
            border_style: Theme.active_border(tui)
          )
        )

        frame.render_widget(paragraph, area)
      end
    end
  end
end
