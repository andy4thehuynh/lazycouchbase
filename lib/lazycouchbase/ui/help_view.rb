# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Keybinding reference shown in help mode.
    class HelpView
      BINDINGS = [
        ["Navigation", ""],
        ["  tab / shift-tab", "cycle panes"],
        ["  1 / 2 / 3", "focus buckets / collections / documents"],
        ["  j / k, arrows", "move selection"],
        ["  g / G", "jump to first / last"],
        ["  enter", "drill in / open document"],
        ["", ""],
        ["Document view", ""],
        ["  j / k", "move the cursor"],
        ["  /", "search lines; n / N next / previous"],
        ["  t", "toggle keys-only outline"],
        ["  y / Y", "copy document / value at cursor"],
        ["", ""],
        ["Query editor", ""],
        ["  enter", "run the query"],
        ["  shift-enter", "insert a newline"],
        ["  ← / →", "move the cursor"],
        ["  ctrl-e", "explain the query (plan + summary)"],
        ["  ↑ / ↓", "recall query history"],
        ["  tab", "pick a SQL++ snippet (ctrl-o opens docs)"],
        ["  esc", "back to the browser"],
        ["", ""],
        ["Actions", ""],
        ["  /", "fuzzy filter the focused pane (↑/↓ move, enter selects)"],
        ["  :", "open the N1QL query editor"],
        ["  i", "toggle indexes / documents in pane 3"],
        ["  r", "refresh the focused pane"],
        ["  esc", "back"],
        ["  ?", "toggle this help"],
        ["  q / ctrl-c", "quit"]
      ].freeze

      TEXT = BINDINGS.map { |keys, action| action.empty? ? keys : "#{keys.ljust(22)} #{action}" }.join("\n").freeze

      def render(tui, frame, area)
        help = tui.paragraph(
          text: TEXT,
          block: tui.block(
            title: " Help ",
            borders: [:all],
            border_style: Theme.active_border(tui)
          )
        )

        frame.render_widget(help, area)
      end
    end
  end
end
