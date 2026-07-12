# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # N1QL query editor with a results panel underneath.
    class QueryView
      CURSOR = "█"

      def render(tui, frame, area, state)
        input_area, results_area = tui.layout_split(
          area,
          direction: :vertical,
          constraints: [tui.constraint_length(input_height(state)), tui.constraint_fill(1)]
        )

        render_input(tui, frame, input_area, state)
        render_results(tui, frame, results_area, state)
      end

      private

      # The input box grows with the query, one row per line plus borders.
      def input_height(state)
        state.query_text.count("\n") + 3
      end

      def render_input(tui, frame, area, state)
        input = tui.paragraph(
          text: state.query_text.dup.insert(state.query_cursor, CURSOR),
          block: tui.block(
            title: " N1QL Query ",
            borders: [:all],
            border_style: Theme.active_border(tui)
          )
        )

        frame.render_widget(input, area)
      end

      def render_results(tui, frame, area, state)
        title = " Results (#{state.query_rows.size})"
        title << " — #{state.query_status}" if state.query_status
        title << " "
        results = tui.paragraph(
          text: state.query_rows.join("\n"),
          wrap: true,
          block: tui.block(
            title: title,
            borders: [:all],
            border_style: Theme.inactive_border(tui)
          )
        )

        frame.render_widget(results, area)
      end
    end
  end
end
