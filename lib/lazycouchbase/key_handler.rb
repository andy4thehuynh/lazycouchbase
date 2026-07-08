# frozen_string_literal: true

module Lazycouchbase
  # Translates keyboard events into state changes and actions.
  #
  # Selection, focus, and mode changes are applied to the AppState directly;
  # anything that needs data (loading collections, running a query, ...) is
  # returned as an action symbol for the App to perform:
  # :quit, :load_collections, :load_documents, :open_document, :run_query,
  # or :refresh. Returns nil when no action is needed.
  class KeyHandler
    PANE_KEYS = { "1" => :buckets, "2" => :collections, "3" => :documents }.freeze
    RELOAD_ACTIONS = { buckets: :load_collections, collections: :load_documents }.freeze
    SCROLL_DELTAS = {
      "j" => 1, "down" => 1, "k" => -1, "up" => -1, "page_down" => 10, "page_up" => -10
    }.freeze

    def initialize(state)
      @state = state
    end

    def call(event)
      return nil unless event.key?
      return :quit if event == :ctrl_c

      case @state.mode
      when :query then query_mode(event)
      when :document then document_mode(event)
      when :help then help_mode(event)
      else normal_mode(event)
      end
    end

    private

    attr_reader :state

    def normal_mode(event)
      case event.code
      when "q" then :quit
      when "r" then :refresh
      when "?" then show_help
      when ":" then open_query
      when "enter" then activate
      else navigation(event)
      end
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

    def show_help
      state.switch_mode(:help)
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
      when :buckets then state.focus(:collections) && nil
      when :collections then state.focus(:documents) && nil
      else state.selected_document && :open_document
      end
    end

    def open_query
      state.switch_mode(:query)
      nil
    end

    def query_mode(event)
      case event.code
      when "esc" then state.switch_mode(:normal) && nil
      when "enter" then state.query_text.strip.empty? ? nil : :run_query
      when "backspace" then delete_query_char
      else append_query(event)
      end
    end

    def delete_query_char
      state.query_text = state.query_text[0...-1]
      nil
    end

    def append_query(event)
      return nil unless printable?(event)

      state.query_text = state.query_text + event.code
      nil
    end

    def printable?(event)
      event.code.length == 1 && (event.modifiers - ["shift"]).empty?
    end

    def document_mode(event)
      case event.code
      when "esc", "q" then state.switch_mode(:normal)
      when "g" then state.document_scroll = 0
      when "G" then state.document_scroll = state.document_body.lines.size
      else scroll_document(event)
      end
      nil
    end

    def scroll_document(event)
      delta = SCROLL_DELTAS[event.code]
      state.document_scroll += delta if delta
    end

    def help_mode(event)
      state.switch_mode(:normal) if %w[esc q ?].include?(event.code)
      nil
    end
  end
end
