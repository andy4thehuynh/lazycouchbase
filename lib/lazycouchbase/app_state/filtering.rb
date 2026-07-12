# frozen_string_literal: true

module Lazycouchbase
  class AppState
    # The filter is a transient, fzf-style picker over the focused pane: it
    # only exists while filter mode is open. Committing selects the
    # highlighted match in the underlying list; cancelling leaves the pane
    # exactly as it was.
    module Filtering
      def start_filter
        switch_mode(:filter)
        @filter_text = ""
        @filter_index = 0
      end

      def filter_text=(value)
        @filter_text = value || ""
        @filter_index = 0
      end

      def filter_matches
        focused_list.select { |item| Fuzzy.match?(@filter_text, item.to_s) }
      end

      def move_filter_selection(delta)
        @filter_index = (@filter_index + delta).clamp(0, [filter_matches.size - 1, 0].max)
      end

      # Returns true when the pane's selection actually moved, so the caller
      # knows whether dependent panes need reloading. With no match to choose,
      # committing degrades to a cancel.
      def commit_filter
        chosen = filter_matches[@filter_index]
        cancel_filter
        return false unless chosen

        target = focused_list.index(chosen)
        changed = target != focused_index
        self.focused_index = target
        changed
      end

      def cancel_filter
        switch_mode(:normal)
        @filter_text = ""
        @filter_index = 0
      end
    end
  end
end
