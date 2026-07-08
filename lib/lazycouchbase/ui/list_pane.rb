# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # A bordered, selectable list. Used for the buckets, collections, and
    # documents panes. Keeps its ListState across frames so scrolling
    # follows the selection.
    class ListPane
      Props = Data.define(:title, :items, :selected, :focused)

      def initialize
        @list_state = RatatuiRuby::ListState.new(nil)
      end

      def render(tui, frame, area, props)
        @list_state.select(props.items.empty? ? nil : props.selected)

        border = props.focused ? Theme.active_border(tui) : Theme.inactive_border(tui)
        list = tui.list(
          items: props.items.map(&:to_s),
          block: tui.block(title: props.title, borders: [:all], border_style: border),
          highlight_style: Theme.highlight(tui),
          highlight_symbol: "❯ "
        )

        frame.render_stateful_widget(list, area, @list_state)
      end
    end
  end
end
