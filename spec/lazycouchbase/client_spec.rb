# frozen_string_literal: true

require "couchbase"

RSpec.describe Lazycouchbase::Client do
  subject(:client) { described_class.new(connection, cluster: cluster) }

  let(:connection) do
    Lazycouchbase::Config::Connection.new(
      host: "db.example.com", username: "admin", password: "secret", bucket: nil
    )
  end
  let(:cluster) { instance_double(Couchbase::Cluster) }

  def collection_ref(scope, collection)
    Lazycouchbase::Client::CollectionRef.new(scope: scope, collection: collection)
  end

  describe "#connection_string" do
    it "prefixes bare hosts with couchbase://" do
      expect(client.connection_string).to eq("couchbase://db.example.com")
    end

    it "leaves full connection strings untouched" do
      secure = described_class.new(connection.with(host: "couchbases://db.example.com"))

      expect(secure.connection_string).to eq("couchbases://db.example.com")
    end
  end

  describe "#connected?" do
    it "is true when a cluster is present" do
      expect(client.connected?).to be(true)
    end

    it "is false before connecting" do
      expect(described_class.new(connection).connected?).to be(false)
    end
  end

  describe "#disconnect" do
    it "disconnects the cluster and forgets it" do
      allow(cluster).to receive(:disconnect)

      client.disconnect

      expect(cluster).to have_received(:disconnect)
      expect(client.connected?).to be(false)
    end

    it "is a no-op when never connected" do
      expect { described_class.new(connection).disconnect }.not_to raise_error
    end
  end

  describe "#bucket_names" do
    it "returns sorted bucket names" do
      settings = %w[travel-sample beer-sample].map do |name|
        instance_double(Couchbase::Management::BucketSettings, name: name)
      end
      manager = instance_double(Couchbase::Management::BucketManager, get_all_buckets: settings)
      allow(cluster).to receive(:buckets).and_return(manager)

      expect(client.bucket_names).to eq(%w[beer-sample travel-sample])
    end

    it "wraps SDK failures in Client::Error" do
      allow(cluster).to receive(:buckets).and_raise(StandardError, "boom")

      expect { client.bucket_names }.to raise_error(Lazycouchbase::Client::Error, /listing buckets.*boom/)
    end
  end

  describe "#collections" do
    it "flattens scopes into scope.collection refs" do
      scopes = [
        instance_double(Couchbase::Management::ScopeSpec, name: "_default",
                                                          collections: [
                                                            instance_double(Couchbase::Management::CollectionSpec,
                                                                            name: "_default")
                                                          ]),
        instance_double(Couchbase::Management::ScopeSpec, name: "inventory",
                                                          collections: %w[airline route].map do |name|
                                                            instance_double(Couchbase::Management::CollectionSpec,
                                                                            name: name)
                                                          end)
      ]
      manager = instance_double(Couchbase::Management::CollectionManager, get_all_scopes: scopes)
      bucket = instance_double(Couchbase::Bucket, collections: manager)
      allow(cluster).to receive(:bucket).with("travel-sample").and_return(bucket)

      refs = client.collections("travel-sample")

      expect(refs.map(&:to_s)).to eq(%w[_default._default inventory.airline inventory.route])
    end
  end

  describe "#document_ids" do
    it "queries META ids from the collection keyspace" do
      result = instance_double(Couchbase::Cluster::QueryResult, rows: %w[doc-1 doc-2])
      allow(cluster).to receive(:query)
        .with("SELECT RAW META(doc).id FROM `travel-sample`.`inventory`.`airline` AS doc LIMIT 25")
        .and_return(result)

      ids = client.document_ids("travel-sample", collection_ref("inventory", "airline"), limit: 25)

      expect(ids).to eq(%w[doc-1 doc-2])
    end

    it "materializes the SDK's lazy rows into an Array" do
      result = instance_double(Couchbase::Cluster::QueryResult, rows: %w[doc-1 doc-2].lazy)
      allow(cluster).to receive(:query).and_return(result)

      ids = client.document_ids("travel-sample", collection_ref("inventory", "airline"))

      expect(ids).to be_an(Array)
      expect(ids).to eq(%w[doc-1 doc-2])
    end

    it "wraps query failures in Client::Error" do
      allow(cluster).to receive(:query).and_raise(StandardError, "no primary index")

      expect do
        client.document_ids("travel-sample", collection_ref("inventory", "airline"))
      end.to raise_error(Lazycouchbase::Client::Error, /no primary index/)
    end
  end

  describe "#document" do
    it "fetches document content through bucket/scope/collection" do
      get_result = instance_double(Couchbase::Collection::GetResult, content: { "name" => "IPA" })
      collection = instance_double(Couchbase::Collection, get: get_result)
      scope = instance_double(Couchbase::Scope, collection: collection)
      bucket = instance_double(Couchbase::Bucket, scope: scope)
      allow(cluster).to receive(:bucket).with("beer-sample").and_return(bucket)

      content = client.document("beer-sample", collection_ref("_default", "_default"), "ipa-1")

      expect(content).to eq({ "name" => "IPA" })
      expect(collection).to have_received(:get).with("ipa-1")
    end
  end

  describe "#explain" do
    it "prefixes EXPLAIN and returns the first row" do
      result = instance_double(Couchbase::Cluster::QueryResult, rows: [{ "plan" => { "#operator" => "Sequence" } }])
      allow(cluster).to receive(:query).with("EXPLAIN SELECT 1").and_return(result)

      expect(client.explain("SELECT 1")).to eq({ "plan" => { "#operator" => "Sequence" } })
    end

    it "does not double-prefix an EXPLAIN query" do
      result = instance_double(Couchbase::Cluster::QueryResult, rows: [{}])
      allow(cluster).to receive(:query).with("EXPLAIN SELECT 1").and_return(result)

      client.explain("explain SELECT 1")

      expect(cluster).to have_received(:query).with("EXPLAIN SELECT 1")
    end
  end

  describe "#query" do
    it "returns rows with a success status and elapsed time" do
      sdk_result = instance_double(Couchbase::Cluster::QueryResult, rows: [{ "count" => 3 }])
      allow(cluster).to receive(:query).with("SELECT 1").and_return(sdk_result)

      result = client.query("SELECT 1")

      expect(result.rows).to eq([{ "count" => 3 }])
      expect(result.status).to eq("success")
      expect(result.elapsed_ms).to be_a(Integer)
    end

    it "materializes the SDK's lazy rows into an Array" do
      sdk_result = instance_double(Couchbase::Cluster::QueryResult, rows: [{ "count" => 3 }].lazy)
      allow(cluster).to receive(:query).with("SELECT 1").and_return(sdk_result)

      result = client.query("SELECT 1")

      expect(result.rows).to be_an(Array)
      expect(result.rows).to eq([{ "count" => 3 }])
    end

    it "wraps syntax errors in Client::Error" do
      allow(cluster).to receive(:query).and_raise(StandardError, "syntax error")

      expect { client.query("SELEKT") }.to raise_error(Lazycouchbase::Client::Error, /syntax error/)
    end
  end

  describe "integration", :integration do
    it "lists buckets on a live cluster" do
      skip_unless_couchbase

      live = described_class.new(
        Lazycouchbase::Config::Connection.new(
          host: CouchbaseHelpers::COUCHBASE_TEST_HOST,
          username: CouchbaseHelpers::COUCHBASE_TEST_USERNAME,
          password: CouchbaseHelpers::COUCHBASE_TEST_PASSWORD,
          bucket: CouchbaseHelpers::COUCHBASE_TEST_BUCKET
        )
      )

      expect(live.connect.bucket_names).to be_an(Array)
    ensure
      live&.disconnect
    end
  end
end
