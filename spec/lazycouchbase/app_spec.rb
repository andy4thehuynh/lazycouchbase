# frozen_string_literal: true

RSpec.describe Lazycouchbase::App, :tui do
  subject(:app) { described_class.new(client: client, config: config, history: history) }

  let(:history) { Lazycouchbase::QueryHistory.new }

  let(:client) do
    FakeClient.new(
      buckets: {
        "beer-sample" => {
          "_default._default" => {
            "ipa-1" => { "name" => "Hoppy IPA", "abv" => 6.5 },
            "stout-1" => { "name" => "Midnight Stout", "abv" => 8.0 }
          }
        },
        "travel-sample" => {
          "inventory.airline" => { "airline_10" => { "name" => "40-Mile Air" } }
        }
      },
      indexes: {
        "beer-sample" => {
          "_default._default" => [
            { "name" => "#primary", "index_key" => [], "state" => "online", "is_primary" => true },
            { "name" => "idx_name", "index_key" => ["`name`"], "state" => "online" }
          ]
        }
      }
    )
  end
  let(:config) { Lazycouchbase::Config.new }

  def run_app(*keys)
    with_test_terminal(100, 30) do
      inject_keys(*keys)
      app.run
    end
  end

  it "loads buckets, collections, and documents on startup" do
    run_app("q")

    expect(app.state.buckets).to eq(%w[beer-sample travel-sample])
    expect(app.state.collections.map(&:to_s)).to eq(%w[_default._default])
    expect(app.state.documents).to eq(%w[ipa-1 stout-1])
    expect(app.state.status_message).to include("Connected to couchbase://test-host")
  end

  it "disconnects the client when the loop ends" do
    run_app("q")

    expect(client).to be_disconnected
  end

  it "quits on ctrl-c" do
    run_app(:ctrl_c)

    expect(client).to be_disconnected
  end

  it "reloads collections when the bucket selection moves" do
    run_app("j", "q")

    expect(app.state.selected_bucket).to eq("travel-sample")
    expect(app.state.collections.map(&:to_s)).to eq(%w[inventory.airline])
    expect(app.state.documents).to eq(%w[airline_10])
  end

  it "opens the selected document in document mode" do
    run_app("3", "j", "enter", :ctrl_c)

    expect(app.state.mode).to eq(:document)
    expect(app.state.doc.id).to eq("stout-1")
    expect(app.state.doc.body).to include("\"name\": \"Midnight Stout\"")
  end

  it "yanks the open document to the clipboard" do
    allow(Lazycouchbase::Clipboard).to receive(:copy).and_return(true)

    run_app("3", "enter", "y", :ctrl_c)

    expect(Lazycouchbase::Clipboard).to have_received(:copy).with(a_string_including("\"name\": \"Hoppy IPA\""))
    expect(app.state.status_message).to eq("Copied document ipa-1")
  end

  it "explains when no clipboard tool is available" do
    allow(Lazycouchbase::Clipboard).to receive(:copy).and_return(false)

    run_app("3", "enter", "Y", :ctrl_c)

    expect(app.state.status_message).to include("No clipboard tool found")
  end

  it "returns from the document view with esc" do
    run_app("3", "enter", "esc", "q")

    expect(app.state.mode).to eq(:normal)
  end

  it "fuzzy filters buckets and loads the committed selection" do
    run_app("/", "t", "enter", "q")

    expect(app.state.selected_bucket).to eq("travel-sample")
    expect(app.state.collections.map(&:to_s)).to eq(%w[inventory.airline])
    expect(app.state.documents).to eq(%w[airline_10])
  end

  it "opens a document found through the fuzzy filter" do
    run_app("3", "/", "s", "enter", "enter", :ctrl_c)

    expect(app.state.mode).to eq(:document)
    expect(app.state.doc.id).to eq("stout-1")
  end

  it "lists the collection's indexes when toggled with i" do
    run_app("i", "q")

    expect(app.state.indexes_shown?).to be(true)
    expect(app.state.indexes.map(&:name)).to eq(["#primary", "idx_name"])
  end

  it "returns to a fresh documents list when toggled back" do
    run_app("i", "i", "q")

    expect(app.state.indexes_shown?).to be(false)
    expect(app.state.documents).to eq(%w[ipa-1 stout-1])
  end

  it "reloads indexes for the new collection when the selection moves" do
    run_app("i", "j", "q")

    expect(app.state.selected_bucket).to eq("travel-sample")
    expect(app.state.indexes_shown?).to be(true)
    expect(app.state.indexes).to be_empty
  end

  it "opens an index definition in the document view" do
    run_app("i", "3", "j", "enter", :ctrl_c)

    expect(app.state.mode).to eq(:document)
    expect(app.state.doc.id).to eq("idx_name")
    expect(app.state.doc.body).to include("index_key")
  end

  it "runs a query typed into the query editor" do
    run_app(":", *"SELECT 1".chars, "enter", :ctrl_c)

    expect(client.executed_queries).to eq(["SELECT 1"])
    expect(app.state.query_rows).to eq(['{"greeting":"hello"}'])
    expect(app.state.status_message).to include("1 rows in 5ms")
  end

  it "records executed queries and recalls them with the up arrow" do
    run_app(":", *"SELECT 1".chars, "enter", :up, "enter", :ctrl_c)

    expect(history.entries).to eq(["SELECT 1"])
    expect(client.executed_queries).to eq(["SELECT 1", "SELECT 1"])
  end

  it "explains the query into the document view" do
    run_app(":", *"SELECT 1".chars, :ctrl_e, :ctrl_c)

    expect(app.state.mode).to eq(:document)
    expect(app.state.doc.id).to eq("EXPLAIN")
    expect(app.state.doc.body).to include("Primary scan on beer-sample")
    expect(app.state.doc.body).to include("\"#operator\": \"PrimaryScan3\"")
  end

  it "inserts a snippet into the query editor with the keyspace filled in" do
    run_app(":", "tab", "enter", :ctrl_c)

    expect(app.state.mode).to eq(:query)
    expect(app.state.query_text).to include("`beer-sample`.`_default`.`_default`")
    expect(app.state.query_text).not_to include("%{keyspace}")
  end

  it "opens the snippet docs in the browser with ctrl-o" do
    allow(Lazycouchbase::Browser).to receive(:open).and_return(true)

    run_app(":", "tab", :ctrl_o, :ctrl_c)

    expect(Lazycouchbase::Browser).to have_received(:open).with(a_string_starting_with("https://"))
    expect(app.state.status_message).to include("Opened https://")
    expect(app.state.mode).to eq(:snippet)
  end

  it "copies the docs url when no browser opener exists" do
    allow(Lazycouchbase::Browser).to receive(:open).and_return(false)
    allow(Lazycouchbase::Clipboard).to receive(:copy).and_return(true)

    run_app(":", "tab", :ctrl_o, :ctrl_c)

    expect(app.state.status_message).to include("copied https://")
  end

  it "shows the docs url when neither browser nor clipboard work" do
    allow(Lazycouchbase::Browser).to receive(:open).and_return(false)
    allow(Lazycouchbase::Clipboard).to receive(:copy).and_return(false)

    run_app(":", "tab", :ctrl_o, :ctrl_c)

    expect(app.state.status_kind).to eq(:error)
    expect(app.state.status_message).to include("Docs: https://")
  end

  it "preselects the configured bucket at startup" do
    bucket_config = Lazycouchbase::Config.new(overrides: { bucket: "travel-sample" })
    picky = described_class.new(client: client, config: bucket_config)

    with_test_terminal(100, 30) do
      inject_keys("q")
      picky.run
    end

    expect(picky.state.selected_bucket).to eq("travel-sample")
    expect(picky.state.documents).to eq(%w[airline_10])
  end

  it "surfaces client errors in the status bar instead of crashing" do
    failing = described_class.new(client: FakeClient.new(error: "cluster unreachable"), config: config)

    with_test_terminal(100, 30) do
      inject_keys("q")
      failing.run
    end

    expect(failing.state.status_kind).to eq(:error)
    expect(failing.state.status_message).to include("cluster unreachable")
  end

  it "keeps a partial-load error visible instead of reporting Connected" do
    flaky_client = FakeClient.new(
      buckets: { "beer-sample" => { "_default._default" => {} } },
      error_on: { document_ids: "no primary index" }
    )
    flaky = described_class.new(client: flaky_client, config: config)

    with_test_terminal(100, 30) do
      inject_keys("q")
      flaky.run
    end

    expect(flaky.state.status_kind).to eq(:error)
    expect(flaky.state.status_message).to include("no primary index")
  end

  it "clears stale collections when a bucket's collections fail to load" do
    flaky = described_class.new(
      client: FakeClient.new(
        buckets: { "beer-sample" => { "_default._default" => {} } },
        error_on: { collections: "permission denied" }
      ),
      config: config
    )

    with_test_terminal(100, 30) do
      inject_keys("q")
      flaky.run
    end

    expect(flaky.state.collections).to be_empty
    expect(flaky.state.status_message).to include("permission denied")
  end

  it "warns when the configured bucket does not exist" do
    typo_config = Lazycouchbase::Config.new(overrides: { bucket: "travel-sampel" })
    picky = described_class.new(client: client, config: typo_config)

    with_test_terminal(100, 30) do
      inject_keys("q")
      picky.run
    end

    expect(picky.state.status_kind).to eq(:error)
    expect(picky.state.status_message).to include("travel-sampel")
    expect(picky.state.selected_bucket).to eq("beer-sample")
  end

  it "keeps the selected bucket when refreshing the buckets pane" do
    run_app("j", "r", :ctrl_c)

    expect(app.state.selected_bucket).to eq("travel-sample")
    expect(app.state.documents).to eq(%w[airline_10])
  end

  it "draws the loaded data to the terminal" do
    screen = nil
    with_test_terminal(100, 30) do
      inject_keys("q")
      app.run
      screen = buffer_content.join("\n")
    end

    expect(screen).to include("beer-sample")
    expect(screen).to include("ipa-1")
    expect(screen).to include("test-host")
  end
end
