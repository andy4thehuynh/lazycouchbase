# frozen_string_literal: true

module Lazycouchbase
  # Thin wrapper around the Couchbase SDK.
  #
  # Exposes just the operations the TUI needs (bucket/collection discovery,
  # document listing and retrieval, ad-hoc N1QL queries) and normalizes SDK
  # failures into Client::Error so the UI can surface them in the status bar.
  # The SDK is only required on first connect, and a pre-built cluster can be
  # injected for tests.
  class Client
    class Error < Lazycouchbase::Error; end

    # Milliseconds to wait for the initial cluster bootstrap; without this the
    # SDK can block for minutes on an unreachable host.
    CONNECT_TIMEOUT_MS = 10_000

    QueryResult = Data.define(:rows, :status, :elapsed_ms)

    CollectionRef = Data.define(:scope, :collection) do
      def to_s
        "#{scope}.#{collection}"
      end
    end

    # One row of system:indexes, with the raw row kept for the detail view.
    IndexInfo = Data.define(:name, :keys, :state, :primary, :condition, :raw) do
      def self.from_row(row)
        new(
          name: row["name"].to_s,
          keys: Array(row["index_key"]),
          state: row["state"].to_s,
          primary: row["is_primary"] == true,
          condition: row["condition"],
          raw: row
        )
      end

      def to_s
        parts = [name]
        parts << "(#{keys.join(", ")})" unless keys.empty?
        parts << "WHERE #{condition}" if condition
        parts << (primary ? "[primary, #{state}]" : "[#{state}]")
        parts.join(" ")
      end
    end

    attr_reader :connection

    def initialize(connection, cluster: nil)
      @connection = connection
      @cluster = cluster
    end

    def connection_string
      host = connection.host
      host.include?("://") ? host : "couchbase://#{host}"
    end

    def connect
      cluster
      self
    end

    def connected?
      !@cluster.nil?
    end

    def disconnect
      @cluster&.disconnect
      @cluster = nil
    end

    def bucket_names
      wrap_errors("listing buckets") do
        cluster.buckets.get_all_buckets.map(&:name).sort
      end
    end

    def collections(bucket_name)
      wrap_errors("listing collections in #{bucket_name}") do
        cluster.bucket(bucket_name).collections.get_all_scopes.flat_map do |scope|
          scope.collections.map { |collection| CollectionRef.new(scope: scope.name, collection: collection.name) }
        end
      end
    end

    def document_ids(bucket_name, ref, limit: 50)
      statement = "SELECT RAW META(doc).id FROM #{keyspace(bucket_name, ref)} AS doc LIMIT #{Integer(limit)}"
      wrap_errors("listing documents in #{bucket_name}.#{ref}") do
        # The SDK's rows is an Enumerator::Lazy; the UI needs a real Array.
        cluster.query(statement).rows.to_a
      end
    end

    def document(bucket_name, ref, id)
      wrap_errors("fetching #{id}") do
        cluster.bucket(bucket_name).scope(ref.scope).collection(ref.collection).get(id).content
      end
    end

    # Indexes covering a collection, from the system:indexes catalog.
    def indexes(bucket_name, ref)
      wrap_errors("listing indexes for #{bucket_name}.#{ref}") do
        cluster.query(index_statement(bucket_name, ref)).rows.to_a.map { |row| IndexInfo.from_row(row) }
      end
    end

    # Returns the raw plan document for a statement (any leading EXPLAIN is
    # stripped first so recalled EXPLAIN queries are not double-prefixed).
    def explain(statement)
      bare = statement.strip.sub(/\Aexplain\s+/i, "")
      wrap_errors("explaining query") do
        cluster.query("EXPLAIN #{bare}").rows.to_a.first || {}
      end
    end

    def query(statement)
      wrap_errors("running query") do
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = cluster.query(statement)
        elapsed_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started) * 1000).round
        QueryResult.new(rows: result.rows.to_a, status: "success", elapsed_ms: elapsed_ms)
      end
    end

    private

    def cluster
      @cluster ||= wrap_errors("connecting to #{connection_string}") do
        require "couchbase"

        # The C++ core logs straight to the terminal, which corrupts the TUI.
        Couchbase.log_level = :off unless ENV["COUCHBASE_BACKEND_LOG_LEVEL"]

        options = Couchbase::Options::Cluster.new
        options.authenticate(connection.username, connection.password)
        options.bootstrap_timeout = CONNECT_TIMEOUT_MS
        Couchbase::Cluster.connect(connection_string, options)
      end
    end

    def keyspace(bucket_name, ref)
      [bucket_name, ref.scope, ref.collection].map { |part| "`#{part}`" }.join(".")
    end

    # Pre-collection "bucket indexes" live on the default collection, where
    # the catalog stores the bucket name as the keyspace with no bucket_id.
    def index_statement(bucket_name, ref)
      scopes = [
        "(idx.bucket_id = #{quote(bucket_name)} AND idx.scope_id = #{quote(ref.scope)} " \
        "AND idx.keyspace_id = #{quote(ref.collection)})"
      ]
      scopes << "(idx.bucket_id IS MISSING AND idx.keyspace_id = #{quote(bucket_name)})" if default_collection?(ref)
      "SELECT idx.* FROM system:indexes AS idx WHERE #{scopes.join(" OR ")} ORDER BY idx.name"
    end

    def default_collection?(ref)
      ref.scope == "_default" && ref.collection == "_default"
    end

    def quote(value)
      %("#{value.to_s.gsub(/["\\]/) { |char| "\\#{char}" }}")
    end

    def wrap_errors(context)
      yield
    rescue Error
      raise
    rescue StandardError => e
      raise Error, "Error #{context}: #{e.message}"
    end
  end
end
