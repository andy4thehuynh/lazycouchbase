# frozen_string_literal: true

RSpec.describe Lazycouchbase::Snippet do
  subject(:snippet) do
    described_class.new(
      name: "Group and count",
      category: "Aggregation",
      template: "SELECT country, COUNT(*) FROM %{keyspace} GROUP BY country",
      description: "Counts documents per country.",
      docs: "https://example.test/groupby.html"
    )
  end

  it "labels itself with category and name" do
    expect(snippet.label).to eq("Aggregation › Group and count")
  end

  it "fills the keyspace placeholder" do
    expect(snippet.statement("`travel-sample`.`inventory`.`airline`"))
      .to eq("SELECT country, COUNT(*) FROM `travel-sample`.`inventory`.`airline` GROUP BY country")
  end

  it "leaves the placeholder visible without a keyspace" do
    expect(snippet.statement(nil)).to include("%{keyspace}")
  end
end
