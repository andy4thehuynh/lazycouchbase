# frozen_string_literal: true

module Lazycouchbase
  # Pure, renderer-agnostic state for the TUI.
  #
  # Holds what is on screen (buckets, collections, documents, query buffer,
  # status line) and where the user is (focused pane, mode, selections).
  # It knows nothing about Couchbase or the terminal, which keeps it fully
  # unit-testable.
  class AppState
    include Filtering
    include QueryEditing

    PANES = %i[buckets collections documents].freeze
    MODES = %i[normal query document document_search help filter snippet].freeze

    attr_reader :mode, :focused_pane, :buckets, :collections, :documents,
                :bucket_index, :collection_index, :document_index,
                :indexes, :index_index,
                :query_text, :query_cursor, :filter_text, :filter_index, :doc
    attr_accessor :query_rows, :query_status, :query_history, :snippets,
                  :status_message, :status_kind, :connection_label

    def initialize
      @mode = :normal
      @focused_pane = :buckets
      @doc = DocumentState.new
      initialize_lists
      initialize_editor
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
      self.indexes = []
    end

    def indexes=(list)
      @indexes = list
      @index_index = 0
    end

    def indexes_shown?
      @show_indexes
    end

    # Flips pane 3 between the collection's documents and its indexes.
    # Returns true when indexes are now shown, so the caller knows which
    # list needs loading.
    def toggle_indexes
      @show_indexes = !@show_indexes
      self.indexes = [] unless @show_indexes
      @show_indexes
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

    def selected_index
      @indexes[@index_index]
    end

    # The sidebar selection as a fully qualified, backtick-quoted
    # `bucket`.`scope`.`collection`, or nil when nothing is selected.
    def keyspace
      return nil unless selected_bucket && selected_collection

      parts = [selected_bucket, *selected_collection.to_s.split(".")]
      parts.map { |part| "`#{part}`" }.join(".")
    end

    # Returns the new index, or nil when the name is unknown.
    def select_bucket(name)
      index = @buckets.index(name)
      @bucket_index = index if index
      index
    end

    # Returns the new index, or nil when the selection did not change.
    def move_selection(delta)
      select_index((focused_index + delta).clamp(0, [focused_list.size - 1, 0].max))
    end

    # Returns the new index, or nil when the selection did not change.
    def select_edge(edge)
      select_index(edge == :first ? 0 : focused_list.size - 1)
    end

    def show_document(id, content)
      @doc.load(id, content)
      @status_message = ""
      switch_mode(:document)
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

    def initialize_lists
      @buckets = []
      @collections = []
      @documents = []
      @indexes = []
      @bucket_index = 0
      @collection_index = 0
      @document_index = 0
      @index_index = 0
      @show_indexes = false
    end

    def initialize_editor
      @query_text = ""
      @query_cursor = 0
      @query_rows = []
      @snippets = SnippetPicker.new([])
      @filter_text = ""
      @filter_index = 0
      @status_message = ""
      @status_kind = :info
      @connection_label = ""
    end

    def select_index(target)
      return nil if focused_list.empty? || target == focused_index

      self.focused_index = target
    end

    # Pane 3 holds either documents or indexes; navigation and filtering
    # follow whichever is on screen.
    def focused_list
      { buckets: @buckets, collections: @collections, documents: main_list }.fetch(@focused_pane)
    end

    def main_list
      indexes_shown? ? @indexes : @documents
    end

    def focused_index
      case @focused_pane
      when :buckets then @bucket_index
      when :collections then @collection_index
      else indexes_shown? ? @index_index : @document_index
      end
    end

    def focused_index=(value)
      case @focused_pane
      when :buckets then @bucket_index = value
      when :collections then @collection_index = value
      when :documents
        indexes_shown? ? @index_index = value : @document_index = value
      end
    end
  end
end
