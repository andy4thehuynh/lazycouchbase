# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Top-level layout: a lazygit-style sidebar (buckets over collections),
    # a main panel whose content follows the mode, and a status bar.
    class MainView
      PANE_LABELS = { buckets: "[1] Buckets", collections: "[2] Collections", documents: "[3] Documents" }.freeze

      def initialize
        @buckets_pane = ListPane.new
        @collections_pane = ListPane.new
        @documents_pane = ListPane.new
        @document_view = DocumentView.new
        @query_view = QueryView.new
        @help_view = HelpView.new
        @status_bar = StatusBar.new
      end

      def render(tui, frame, state)
        body, status = tui.layout_split(
          frame.area,
          direction: :vertical,
          constraints: [tui.constraint_fill(1), tui.constraint_length(1)]
        )

        if state.mode == :help
          @help_view.render(tui, frame, body)
        else
          render_body(tui, frame, body, state)
        end
        @status_bar.render(tui, frame, status, state)
      end

      private

      def render_body(tui, frame, area, state)
        sidebar, main = tui.layout_split(
          area,
          direction: :horizontal,
          constraints: [tui.constraint_percentage(30), tui.constraint_fill(1)]
        )

        render_sidebar(tui, frame, sidebar, state)
        render_main(tui, frame, main, state)
      end

      def render_sidebar(tui, frame, area, state)
        buckets_area, collections_area = tui.layout_split(
          area,
          direction: :vertical,
          constraints: [tui.constraint_percentage(40), tui.constraint_fill(1)]
        )

        @buckets_pane.render(tui, frame, buckets_area,
                             props(state, :buckets, state.buckets, state.bucket_index))
        @collections_pane.render(tui, frame, collections_area,
                                 props(state, :collections, state.collections, state.collection_index))
      end

      def render_main(tui, frame, area, state)
        case state.mode
        when :document then @document_view.render(tui, frame, area, state)
        when :query then @query_view.render(tui, frame, area, state)
        else
          @documents_pane.render(tui, frame, area,
                                 props(state, :documents, state.documents, state.document_index))
        end
      end

      def props(state, pane, items, selected)
        ListPane::Props.new(
          title: " #{PANE_LABELS.fetch(pane)} (#{items.size}) ",
          items: items,
          selected: selected,
          focused: state.focused_pane == pane
        )
      end
    end
  end
end
