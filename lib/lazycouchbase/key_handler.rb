# frozen_string_literal: true

module Lazycouchbase
  # Translates keyboard events into state changes and actions.
  #
  # Selection, focus, and mode changes are applied to the AppState directly;
  # anything that needs data or IO (loading collections, running a query,
  # yanking to the clipboard, ...) is returned as an action symbol for the
  # App to perform: :quit, :load_collections, :load_documents,
  # :open_document, :run_query, :refresh, :yank_document, or :yank_value.
  # Returns nil when no action is needed.
  class KeyHandler
    PANE_KEYS = { "1" => :buckets, "2" => :collections, "3" => :documents }.freeze
    RELOAD_ACTIONS = { buckets: :load_collections, collections: :load_documents }.freeze

    def self.printable?(event)
      event.code.length == 1 && (event.modifiers - ["shift"]).empty?
    end

    def initialize(state)
      @state = state
      @document_keys = DocumentKeys.new(state)
    end

    def call(event)
      return nil unless event.key?
      return :quit if event == :ctrl_c

      mode_keys(event)
    end

    private

    attr_reader :state

    def mode_keys(event)
      case @state.mode
      when :query then query_mode(event)
      when :document then @document_keys.document(event)
      when :document_search then @document_keys.search(event)
      when :help then help_mode(event)
      when :filter then filter_mode(event)
      else normal_mode(event)
      end
    end

    def normal_mode(event)
      case event.code
      when "q" then :quit
      when "r" then :refresh
      when "?" then switch(:help)
      when ":" then switch(:query)
      when "/" then open_filter
      when "enter" then activate
      else navigation(event)
      end
    end

    def switch(mode)
      state.switch_mode(mode)
      nil
    end

    def navigation(event)
      case event.code
      when "j", "down" then move(1)
      when "k", "up" then move(-1)
      when "g" then jump(:first)
      when "G" then jump(:last)
      else focus_keys(event)
      end
    end

    def focus_keys(event)
      case event.code
      when "tab" then state.focus_next
      when "back_tab" then state.focus_previous
      when *PANE_KEYS.keys then state.focus(PANE_KEYS.fetch(event.code))
      end
      nil
    end

    def move(delta)
      state.move_selection(delta) ? RELOAD_ACTIONS[state.focused_pane] : nil
    end

    def jump(edge)
      state.select_edge(edge) ? RELOAD_ACTIONS[state.focused_pane] : nil
    end

    def activate
      case state.focused_pane
      when :buckets then focus_pane(:collections)
      when :collections then focus_pane(:documents)
      else state.selected_document && :open_document
      end
    end

    def focus_pane(pane)
      state.focus(pane)
      nil
    end

    def close_query
      state.query_history&.reset_position
      state.switch_mode(:normal)
      nil
    end

    def query_mode(event)
      return query_action(:explain_query) if event == :ctrl_e

      case event.code
      when "esc" then close_query
      when "enter" then query_action(:run_query)
      when "backspace" then delete_query_char
      when "up" then recall_query(:previous)
      when "down" then recall_query(:next)
      else append_query(event)
      end
    end

    def query_action(action)
      state.query_text.strip.empty? ? nil : action
    end

    def recall_query(direction)
      history = state.query_history
      return nil unless history

      replacement = direction == :previous ? history.recall_previous : history.recall_next
      state.query_text = replacement if replacement
      nil
    end

    def delete_query_char
      state.query_text = state.query_text[0...-1]
      nil
    end

    def append_query(event)
      return nil unless self.class.printable?(event)

      state.query_text = state.query_text + event.code
      nil
    end

    def open_filter
      state.start_filter
      nil
    end

    def filter_mode(event)
      case event.code
      when "esc" then close_filter
      when "enter" then commit_filter
      when "backspace" then delete_filter_char
      when "up" then move_filter(-1)
      when "down" then move_filter(1)
      else append_filter(event)
      end
    end

    def close_filter
      state.cancel_filter
      nil
    end

    def commit_filter
      state.commit_filter ? RELOAD_ACTIONS[state.focused_pane] : nil
    end

    def delete_filter_char
      state.filter_text = state.filter_text[0...-1]
      nil
    end

    def move_filter(delta)
      state.move_filter_selection(delta)
      nil
    end

    def append_filter(event)
      return nil unless self.class.printable?(event)

      state.filter_text = state.filter_text + event.code
      nil
    end

    def help_mode(event)
      state.switch_mode(:normal) if %w[esc q ?].include?(event.code)
      nil
    end
  end
end
