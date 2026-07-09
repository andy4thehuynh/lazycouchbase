# frozen_string_literal: true

RSpec.describe Lazycouchbase::Fuzzy do
  it "matches everything with an empty query" do
    expect(described_class.match?("", "beer-sample")).to be(true)
  end

  it "matches exact substrings" do
    expect(described_class.match?("game", "gamesim-sample")).to be(true)
  end

  it "matches non-adjacent subsequences" do
    expect(described_class.match?("ta2", "tenant_agent_02.users")).to be(true)
  end

  it "is case-insensitive in both directions" do
    expect(described_class.match?("GAME", "gamesim-sample")).to be(true)
    expect(described_class.match?("game", "GAMESIM-SAMPLE")).to be(true)
  end

  it "rejects characters out of order" do
    expect(described_class.match?("mag", "gamesim-sample")).to be(false)
  end

  it "rejects absent characters" do
    expect(described_class.match?("z", "gamesim-sample")).to be(false)
  end

  it "matches non-string candidates through to_s" do
    ref = Lazycouchbase::Client::CollectionRef.new(scope: "inventory", collection: "airline")

    expect(described_class.match?("invair", ref)).to be(true)
  end
end
