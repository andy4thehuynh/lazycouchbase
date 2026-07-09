# frozen_string_literal: true

# In-memory stand-in for Lazycouchbase::Client.
#
# Data is a nested hash: bucket name => "scope.collection" => id => content.
# Pass +error:+ to make every data method raise Client::Error, +error_on:+
# (method name => message) to fail specific methods only, and
# +query_result:+ to canned-answer #query.
class FakeClient
  attr_reader :connection, :executed_queries

  DEFAULT_QUERY_RESULT = Lazycouchbase::Client::QueryResult.new(
    rows: [{ "greeting" => "hello" }], status: "success", elapsed_ms: 5
  )

  def initialize(buckets: {}, connection: nil, query_result: DEFAULT_QUERY_RESULT, error: nil, error_on: {})
    @buckets = buckets
    @connection = connection || Lazycouchbase::Config::Connection.new(
      host: "test-host", username: "tester", password: "secret", bucket: nil
    )
    @query_result = query_result
    @error = error
    @error_on = error_on
    @executed_queries = []
    @disconnected = false
  end

  def connection_string
    "couchbase://#{connection.host}"
  end

  def connect
    self
  end

  def connected?
    !@disconnected
  end

  def disconnect
    @disconnected = true
  end

  def disconnected?
    @disconnected
  end

  def bucket_names
    fail_if_configured(:bucket_names)
    @buckets.keys.sort
  end

  def collections(bucket_name)
    fail_if_configured(:collections)
    @buckets.fetch(bucket_name, {}).keys.map do |key|
      scope, collection = key.split(".", 2)
      Lazycouchbase::Client::CollectionRef.new(scope: scope, collection: collection)
    end
  end

  def document_ids(bucket_name, ref, limit: 50)
    fail_if_configured(:document_ids)
    documents_in(bucket_name, ref).keys.first(limit)
  end

  def document(bucket_name, ref, id)
    fail_if_configured(:document)
    documents_in(bucket_name, ref).fetch(id)
  end

  def query(statement)
    fail_if_configured(:query)
    @executed_queries << statement
    @query_result
  end

  def explain(statement)
    fail_if_configured(:explain)
    @executed_queries << "EXPLAIN #{statement}"
    {
      "plan" => {
        "#operator" => "Sequence",
        "~children" => [
          { "#operator" => "PrimaryScan3", "keyspace" => "beer-sample" },
          { "#operator" => "Fetch", "keyspace" => "beer-sample" }
        ]
      }
    }
  end

  private

  def documents_in(bucket_name, ref)
    @buckets.fetch(bucket_name, {}).fetch(ref.to_s, {})
  end

  def fail_if_configured(method)
    raise Lazycouchbase::Client::Error, @error if @error

    message = @error_on[method]
    raise Lazycouchbase::Client::Error, message if message
  end
end
