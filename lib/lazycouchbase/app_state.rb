# frozen_string_literal: true

module Lazycouchbase
  # Pure, renderer-agnostic state for the TUI.
  #
  # Holds what is on screen (buckets, collections, documents, query buffer,
  # status line) and where the user is (focused pane, mode, selections).
  # It knows nothing about Couchbase or the terminal, which keeps it fully
  # unit-testable.
  class AppState
    PANES = %i[buckets collections documents].freeze
    MODES = %i[normal query document help].freeze

    attr_reader :mode, :focused_pane, :buckets, :collections, :documents,
                :bucket_index, :collection_index, :document_index,
                :query_text, :document_scroll
    attr_accessor :document_id, :document_body, :query_rows, :query_status,
                  :status_message, :status_kind, :connection_label

    def initialize
      @mode = :normal
      @focused_pane = :buckets
      @buckets = []
      @collections = []
      @documents = []
      @bucket_index = 0
      @collection_index = 0
      @document_index = 0
      @document_body = ""
      @document_scroll = 0
      @query_text = ""
      @query_rows = []
      @status_message = ""
      @status_kind = :info
      @connection_label = ""
    end

    def switch_mode(mode)
      raise ArgumentError, "unknown mode #{mode.inspect}" unless MODES.include?(mode)

      @mode = mode
    end

    def focus(pane)
      raise ArgumentError, "unknown pane #{pane.inspect}" unless PANES.include?(pane)

      @focused_pane = pane
    end

    def focus_next
      focus(PANES[(PANES.index(@focused_pane) + 1) % PANES.size])
    end

    def focus_previous
      focus(PANES[(PANES.index(@focused_pane) - 1) % PANES.size])
    end

    def buckets=(names)
      @buckets = names
      @bucket_index = 0
      self.collections = []
    end

    def collections=(refs)
      @collections = refs
      @collection_index = 0
      self.documents = []
    end

    def documents=(ids)
      @documents = ids
      @document_index = 0
    end

    def selected_bucket
      @buckets[@bucket_index]
    end

    def selected_collection
      @collections[@collection_index]
    end

    def selected_document
      @documents[@document_index]
    end

    # Returns the new index, or nil when the name is unknown.
    def select_bucket(name)
      index = @buckets.index(name)
      @bucket_index = index if index
      index
    end

    # Returns the new index, or nil when the selection did not change.
    def move_selection(delta)
      list = focused_list
      return nil if list.empty?

      target = (focused_index + delta).clamp(0, list.size - 1)
      return nil if target == focused_index

      self.focused_index = target
    end

    def select_edge(edge)
      move_selection(edge == :first ? -focused_list.size : focused_list.size)
    end

    def document_scroll=(value)
      max = [document_body.lines.size - 1, 0].max
      @document_scroll = value.clamp(0, max)
    end

    def query_text=(value)
      @query_text = value || ""
    end

    def info(message)
      @status_message = message
      @status_kind = :info
    end

    def error(message)
      @status_message = message
      @status_kind = :error
    end

    private

    def focused_list
      { buckets: @buckets, collections: @collections, documents: @documents }.fetch(@focused_pane)
    end

    def focused_index
      { buckets: @bucket_index, collections: @collection_index, documents: @document_index }.fetch(@focused_pane)
    end

    def focused_index=(value)
      case @focused_pane
      when :buckets then @bucket_index = value
      when :collections then @collection_index = value
      else @document_index = value
      end
    end
  end
end
