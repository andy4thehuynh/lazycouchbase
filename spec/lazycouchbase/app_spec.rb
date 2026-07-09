# frozen_string_literal: true

RSpec.describe Lazycouchbase::App, :tui do
  subject(:app) { described_class.new(client: client, config: config) }

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
    expect(app.state.document_id).to eq("stout-1")
    expect(app.state.document_body).to include("\"name\": \"Midnight Stout\"")
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
    expect(app.state.document_id).to eq("stout-1")
  end

  it "runs a query typed into the query editor" do
    run_app(":", *"SELECT 1".chars, "enter", :ctrl_c)

    expect(client.executed_queries).to eq(["SELECT 1"])
    expect(app.state.query_rows).to eq(['{"greeting":"hello"}'])
    expect(app.state.status_message).to include("1 rows in 5ms")
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
