# frozen_string_literal: true

module Lazycouchbase
  class KeyHandler
    # Key bindings for the document view and its line search: cursor
    # movement, search, the keys-only outline, and yank actions.
    class DocumentKeys
      SCROLL_DELTAS = {
        "j" => 1, "down" => 1, "k" => -1, "up" => -1, "page_down" => 10, "page_up" => -10
      }.freeze

      def initialize(state)
        @state = state
      end

      def document(event)
        return outline(event) if doc.outline?

        case event.code
        when "esc", "q" then close
        when "/" then open_search
        when "t" then toggle_outline
        when "y" then :yank_document
        when "Y" then :yank_value
        else document_navigation(event)
        end
      end

      def search(event)
        case event.code
        when "esc" then cancel_search
        when "enter" then close_search
        when "backspace" then delete_search_char
        else append_search(event)
        end
      end

      private

      attr_reader :state

      def document_navigation(event)
        case event.code
        when "n" then next_match(1)
        when "N" then next_match(-1)
        when "g" then edge(:first)
        when "G" then edge(:last)
        else move_cursor(event)
        end
      end

      def outline(event)
        case event.code
        when "esc", "t" then doc.toggle_outline
        when "q" then return close
        when "enter" then doc.commit_outline_selection
        when "j", "down" then doc.move_outline_selection(1)
        when "k", "up" then doc.move_outline_selection(-1)
        end
        nil
      end

      def close
        state.switch_mode(:normal)
        nil
      end

      def open_search
        doc.start_search
        state.switch_mode(:document_search)
        nil
      end

      def cancel_search
        doc.cancel_search
        state.switch_mode(:document)
        nil
      end

      def close_search
        state.switch_mode(:document)
        nil
      end

      def delete_search_char
        doc.search_text = doc.search_text[0...-1]
        nil
      end

      def append_search(event)
        return nil unless KeyHandler.printable?(event)

        doc.search_text = doc.search_text + event.code
        nil
      end

      def next_match(direction)
        doc.next_match(direction)
        nil
      end

      def toggle_outline
        if doc.outline_available?
          doc.toggle_outline
        else
          state.info("No keys to outline")
        end
        nil
      end

      def edge(edge)
        doc.cursor_edge(edge)
        nil
      end

      def move_cursor(event)
        delta = SCROLL_DELTAS[event.code]
        doc.move_cursor(delta) if delta
        nil
      end

      def doc
        state.doc
      end
    end
  end
end
