# frozen_string_literal: true

RSpec.describe Lazycouchbase::SnippetPicker do
  subject(:picker) { described_class.new(snippets) }

  let(:snippets) do
    [
      build_snippet(name: "Select fields", category: "Basics"),
      build_snippet(name: "Group and count", category: "Aggregation"),
      build_snippet(name: "Flatten with UNNEST", category: "Arrays")
    ]
  end

  def build_snippet(name:, category:)
    Lazycouchbase::Snippet.new(
      name: name, category: category, template: "SELECT 1",
      description: "#{name}.", docs: "https://example.test"
    )
  end

  it "matches everything with an empty query" do
    expect(picker.matches).to eq(snippets)
    expect(picker.total).to eq(3)
  end

  it "fuzzy matches against the category › name label" do
    picker.text = "aggcount"

    expect(picker.matches.map(&:name)).to eq(["Group and count"])
  end

  it "resets the highlight when the query changes" do
    picker.move(2)

    picker.text = "s"

    expect(picker.index).to eq(0)
  end

  it "clamps the highlight within the matches" do
    picker.move(10)
    expect(picker.index).to eq(2)

    picker.move(-10)
    expect(picker.index).to eq(0)
  end

  it "returns the highlighted snippet" do
    picker.move(1)

    expect(picker.selected.name).to eq("Group and count")
  end

  it "returns nil when nothing matches" do
    picker.text = "zzz"

    expect(picker.selected).to be_nil
  end

  it "clears the query and highlight on reset" do
    picker.text = "unnest"
    picker.move(1)

    picker.reset

    expect(picker.text).to eq("")
    expect(picker.index).to eq(0)
  end

  it "knows when it has no snippets and carries loader warnings" do
    empty = described_class.new([], warnings: ["Skipped snippet 2 (missing docs)"])

    expect(empty).to be_empty
    expect(empty.warnings).to eq(["Skipped snippet 2 (missing docs)"])
  end
end
