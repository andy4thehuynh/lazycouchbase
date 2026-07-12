# frozen_string_literal: true

RSpec.describe Lazycouchbase::Snippet do
  subject(:snippet) do
    described_class.new(
      name: "Group and count",
      category: "Aggregation",
      template: "SELECT f1, COUNT(*) FROM %{keyspace} GROUP BY f1",
      example: "SELECT country, COUNT(*) FROM `travel-sample`.inventory.airline GROUP BY country",
      description: "Counts documents per group.",
      docs: "https://example.test/groupby.html"
    )
  end

  it "labels itself with category and name" do
    expect(snippet.label).to eq("Aggregation › Group and count")
  end

  it "fills the keyspace placeholder" do
    expect(snippet.statement("`beer-sample`.`_default`.`_default`"))
      .to eq("SELECT f1, COUNT(*) FROM `beer-sample`.`_default`.`_default` GROUP BY f1")
  end

  it "leaves the placeholder visible without a keyspace" do
    expect(snippet.statement(nil)).to include("%{keyspace}")
  end
end
