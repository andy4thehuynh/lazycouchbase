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
        ["Actions", ""],
        ["  :", "open the N1QL query editor"],
        ["  r", "refresh the focused pane"],
        ["  esc", "back"],
        ["  ?", "toggle this help"],
        ["  q / ctrl-c", "quit"]
      ].freeze

      def render(tui, frame, area)
        text = BINDINGS.map { |keys, action| action.empty? ? keys : "#{keys.ljust(22)} #{action}" }.join("\n")
        help = tui.paragraph(
          text: text,
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
