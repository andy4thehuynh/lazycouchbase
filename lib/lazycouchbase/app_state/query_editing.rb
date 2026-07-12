# frozen_string_literal: true

module Lazycouchbase
  class AppState
    # Cursor-based editing for the query text: the query is a flat string
    # (newlines included) with an insertion point the arrow keys move.
    module QueryEditing
      # Replacing the text wholesale (history recall, snippet insertion)
      # parks the cursor at the end; editing happens at the cursor.
      def query_text=(value)
        @query_text = value || ""
        @query_cursor = @query_text.length
      end

      def insert_query(text)
        @query_text = @query_text.dup.insert(@query_cursor, text)
        @query_cursor += text.length
      end

      # Backspace semantics: removing the character before the cursor also
      # joins lines, so backspacing at the start of an empty line removes it.
      def delete_query_char
        return if @query_cursor.zero?

        @query_text = @query_text[0...(@query_cursor - 1)] + @query_text[@query_cursor..]
        @query_cursor -= 1
      end

      def move_query_cursor(delta)
        @query_cursor = (@query_cursor + delta).clamp(0, @query_text.length)
      end
    end
  end
end
