# frozen_string_literal: true

module Lazycouchbase
  class KeyHandler
    # Key bindings for the query editor and its snippet picker: text entry,
    # history recall, snippet insertion, and the docs link.
    class QueryKeys
      def initialize(state)
        @state = state
      end

      def query(event)
        return action(:explain_query) if event == :ctrl_e

        case event.code
        when "esc" then close
        when "enter" then action(:run_query)
        when "tab" then open_snippets
        else edit(event)
        end
      end

      def snippet(event)
        return docs_action if event == :ctrl_o

        case event.code
        when "esc" then close_snippets
        when "enter" then insert_snippet
        when "backspace" then delete_picker_char
        when "up" then move_picker(-1)
        when "down" then move_picker(1)
        else append_picker(event)
        end
      end

      private

      attr_reader :state

      def edit(event)
        case event.code
        when "backspace" then delete_char
        when "up" then recall(:previous)
        when "down" then recall(:next)
        else append(event)
        end
      end

      def close
        state.query_history&.reset_position
        state.switch_mode(:normal)
        nil
      end

      def action(name)
        state.query_text.strip.empty? ? nil : name
      end

      def recall(direction)
        history = state.query_history
        return nil unless history

        replacement = direction == :previous ? history.recall_previous : history.recall_next
        state.query_text = replacement if replacement
        nil
      end

      def delete_char
        state.query_text = state.query_text[0...-1]
        nil
      end

      def append(event)
        return nil unless KeyHandler.printable?(event)

        state.query_text = state.query_text + event.code
        nil
      end

      def open_snippets
        if picker.empty?
          state.error("No snippets available")
        else
          picker.reset
          state.switch_mode(:snippet)
          state.info(picker.warnings.first) if picker.warnings.any?
        end
        nil
      end

      def close_snippets
        state.switch_mode(:query)
        nil
      end

      # With no match to insert, committing degrades to a cancel — the same
      # contract as the pane filter.
      def insert_snippet
        snippet = picker.selected
        state.switch_mode(:query)
        return nil unless snippet

        state.query_text = snippet.statement(state.keyspace)
        state.info(snippet.description)
        nil
      end

      def docs_action
        picker.selected ? :open_docs : nil
      end

      def delete_picker_char
        picker.text = picker.text[0...-1]
        nil
      end

      def move_picker(delta)
        picker.move(delta)
        nil
      end

      def append_picker(event)
        return nil unless KeyHandler.printable?(event)

        picker.text = picker.text + event.code
        nil
      end

      def picker
        state.snippets
      end
    end
  end
end
