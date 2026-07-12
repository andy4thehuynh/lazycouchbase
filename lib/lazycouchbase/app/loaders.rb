# frozen_string_literal: true

module Lazycouchbase
  class App
    # The data-loading half of the App: everything that fetches from the
    # Client and lands in AppState, with failures routed to the status bar
    # through +guard+.
    module Loaders
      private

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

      def load_collections
        bucket = @state.selected_bucket
        return unless bucket

        if guard { @state.collections = @client.collections(bucket) }
          load_documents
        else
          @state.collections = []
        end
      end

      # Pane 3 shows one list at a time, so only the active one is fetched;
      # toggling back reloads the other.
      def load_documents
        return load_indexes if @state.indexes_shown?

        bucket = @state.selected_bucket
        ref = @state.selected_collection
        return unless bucket && ref

        loaded = guard { @state.documents = @client.document_ids(bucket, ref, limit: @config.document_limit) }
        @state.documents = [] unless loaded
      end

      def load_indexes
        bucket = @state.selected_bucket
        ref = @state.selected_collection
        return unless bucket && ref

        loaded = guard { @state.indexes = @client.indexes(bucket, ref) }
        @state.indexes = [] unless loaded
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
    end
  end
end
