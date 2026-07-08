# frozen_string_literal: true

require "json"
require "ratatui_ruby"

module Lazycouchbase
  # The event loop: owns the terminal session, feeds key events through the
  # KeyHandler, and performs the data-loading actions it returns against the
  # Client. Client failures land in the status bar instead of crashing.
  class App
    POLL_TIMEOUT = 0.05

    attr_reader :state

    def initialize(client:, config:, state: AppState.new, view: UI::MainView.new)
      @client = client
      @config = config
      @state = state
      @view = view
      @key_handler = KeyHandler.new(state)
    end

    def run
      RatatuiRuby.run do |tui|
        @state.connection_label = @client.connection.host
        @state.info("Connecting to #{@client.connection_string}...")
        draw(tui)
        bootstrap
        draw(tui)
        event_loop(tui)
      end
      self
    ensure
      @client.disconnect
    end

    private

    # Redraws only after an event was handled: an idle TUI stays idle.
    def event_loop(tui)
      loop do
        event = tui.poll_event(timeout: POLL_TIMEOUT)
        next if event.none?
        break if perform(@key_handler.call(event)) == :quit

        draw(tui)
      end
    end

    def draw(tui)
      tui.draw { |frame| @view.render(tui, frame, @state) }
    end

    def bootstrap
      return unless guard { @state.buckets = @client.bucket_names }

      @state.info("Connected to #{@client.connection_string}")
      select_configured_bucket
      load_collections
    end

    # An unknown --bucket/-b should not silently land the user in the first
    # bucket without a word.
    def select_configured_bucket
      wanted = @config.connection.bucket
      return if wanted.nil? || @state.select_bucket(wanted)

      @state.error("Bucket #{wanted.inspect} not found")
    end

    def perform(action)
      case action
      when :quit then :quit
      when :load_collections then load_collections
      when :load_documents then load_documents
      when :open_document then open_document
      when :run_query then run_query
      when :refresh then refresh
      end
    end

    def load_collections
      bucket = @state.selected_bucket
      return unless bucket

      if guard { @state.collections = @client.collections(bucket) }
        load_documents
      else
        @state.collections = []
      end
    end

    def load_documents
      bucket = @state.selected_bucket
      ref = @state.selected_collection
      return unless bucket && ref

      loaded = guard { @state.documents = @client.document_ids(bucket, ref, limit: @config.document_limit) }
      @state.documents = [] unless loaded
    end

    def open_document
      id = @state.selected_document
      guard do
        content = @client.document(@state.selected_bucket, @state.selected_collection, id)
        @state.document_id = id
        @state.document_body = pretty(content)
        @state.document_scroll = 0
        @state.switch_mode(:document)
      end
    end

    def run_query
      guard do
        result = @client.query(@state.query_text)
        @state.query_rows = result.rows.map { |row| flat(row) }
        @state.query_status = "#{result.status} in #{result.elapsed_ms}ms"
        @state.info("Query returned #{result.rows.size} rows in #{result.elapsed_ms}ms")
      end
    end

    def refresh
      case @state.focused_pane
      when :buckets then refresh_buckets
      when :collections then load_collections
      else load_documents
      end
    end

    def refresh_buckets
      current = @state.selected_bucket
      return unless guard { @state.buckets = @client.bucket_names }

      @state.select_bucket(current) if current
      load_collections
    end

    # Documents are not guaranteed to be JSON-serializable (binary blobs,
    # non-UTF-8 strings); fall back to #inspect rather than crash the TUI.
    def pretty(content)
      content.is_a?(String) ? content : JSON.pretty_generate(content)
    rescue StandardError
      content.inspect
    end

    def flat(row)
      row.is_a?(String) ? row : JSON.generate(row)
    rescue StandardError
      row.inspect
    end

    def guard
      yield
      true
    rescue Client::Error => e
      @state.error(e.message)
      false
    end
  end
end
