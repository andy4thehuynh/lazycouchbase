# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Full-pane, scrollable view of a single document's pretty-printed JSON.
    class DocumentView
      def render(tui, frame, area, state)
        paragraph = tui.paragraph(
          text: state.document_body,
          wrap: true,
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
