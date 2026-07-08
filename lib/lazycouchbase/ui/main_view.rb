# frozen_string_literal: true

require "ratatui_ruby"

module Lazycouchbase
  module UI
    # Top-level layout: a lazygit-style sidebar (buckets over collections),
    # a main panel whose content follows the mode, and a status bar.
    class MainView
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

        @buckets_pane.render(tui, frame, buckets_area, ListPane::Props.new(
                                                         title: " [1] Buckets (#{state.buckets.size}) ",
                                                         items: state.buckets, selected: state.bucket_index,
                                                         focused: state.focused_pane == :buckets
                                                       ))
        @collections_pane.render(tui, frame, collections_area, ListPane::Props.new(
                                                                 title: " [2] Collections (#{state.collections.size}) ",
                                                                 items: state.collections,
                                                                 selected: state.collection_index,
                                                                 focused: state.focused_pane == :collections
                                                               ))
      end

      def render_main(tui, frame, area, state)
        case state.mode
        when :document then @document_view.render(tui, frame, area, state)
        when :query then @query_view.render(tui, frame, area, state)
        else
          @documents_pane.render(tui, frame, area, ListPane::Props.new(
                                                     title: " [3] Documents (#{state.documents.size}) ",
                                                     items: state.documents, selected: state.document_index,
                                                     focused: state.focused_pane == :documents
                                                   ))
        end
      end
    end
  end
end
