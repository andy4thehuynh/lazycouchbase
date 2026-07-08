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
        bootstrap
        loop do
          tui.draw { |frame| @view.render(tui, frame, @state) }
          event = tui.poll_event(timeout: POLL_TIMEOUT)
          next if event.none?
          break if perform(@key_handler.call(event)) == :quit
        end
      end
      self
    ensure
      @client.disconnect
    end

    private

    def bootstrap
      @state.connection_label = @client.connection.host
      return unless guard { @state.buckets = @client.bucket_names }

      @state.select_bucket(@config.connection.bucket) if @config.connection.bucket
      load_collections
      @state.info("Connected to #{@client.connection_string}")
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

      guard { @state.collections = @client.collections(bucket) } && load_documents
    end

    def load_documents
      bucket = @state.selected_bucket
      ref = @state.selected_collection
      return unless bucket && ref

      guard { @state.documents = @client.document_ids(bucket, ref, limit: @config.document_limit) }
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
        @state.query_rows = result.rows.map { |row| row.is_a?(String) ? row : JSON.generate(row) }
        @state.query_status = "#{result.status} in #{result.elapsed_ms}ms"
        @state.info("Query returned #{result.rows.size} rows in #{result.elapsed_ms}ms")
      end
    end

    def refresh
      case @state.focused_pane
      when :buckets then guard { @state.buckets = @client.bucket_names } && load_collections
      when :collections then load_collections
      else load_documents
      end
    end

    def pretty(content)
      content.is_a?(String) ? content : JSON.pretty_generate(content)
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
