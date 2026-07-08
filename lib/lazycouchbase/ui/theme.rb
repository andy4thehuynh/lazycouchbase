# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Shared styles so every pane looks like part of the same application.
    module Theme
      module_function

      def active_border(tui)
        tui.style(fg: :cyan, modifiers: [:bold])
      end

      def inactive_border(tui)
        tui.style(fg: :dark_gray)
      end

      def highlight(tui)
        tui.style(bg: :blue, fg: :white, modifiers: [:bold])
      end

      def status(tui, kind)
        kind == :error ? tui.style(fg: :red, modifiers: [:bold]) : tui.style(fg: :green)
      end

      def hint(tui)
        tui.style(fg: :dark_gray)
      end
    end
  end
end
