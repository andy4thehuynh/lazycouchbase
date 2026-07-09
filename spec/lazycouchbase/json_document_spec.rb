# frozen_string_literal: true

require "json"

RSpec.describe Lazycouchbase::JsonDocument do
  subject(:document) { described_class.new(content) }

  let(:content) do
    {
      "name" => "Amendment Pale Ale",
      "abv" => 5.2,
      "geo" => { "lat" => 48.596219, "accuracy" => "ROOFTOP" },
      "codes" => [10, 20],
      "brewery" => nil,
      "empty" => {}
    }
  end

  it "renders text identical to JSON.pretty_generate" do
    expect(document.lines.map(&:text).join("\n")).to eq(JSON.pretty_generate(content))
  end

  it "annotates scalar lines with their dot-path and node" do
    lat = document.lines.find { |line| line.text.include?("\"lat\"") }

    expect(lat.path).to eq("geo.lat")
    expect(lat.node).to eq(48.596219)
  end

  it "annotates array elements with indexed paths" do
    element = document.lines.find { |line| line.text.strip == "10," }

    expect(element.path).to eq("codes[0]")
  end

  it "gives closing braces the container's path" do
    closer = document.lines.find { |line| line.text == "  }," }

    expect(closer.path).to eq("geo")
    expect(closer.node).to eq(content["geo"])
  end

  it "builds a keys-only outline pointing at the key lines" do
    expect(document.outline.map(&:text)).to eq(["name", "abv", "geo", "  lat", "  accuracy", "codes", "brewery",
                                                "empty"])

    geo = document.outline.find { |entry| entry.text == "geo" }
    expect(document.lines[geo.line].text).to eq("  \"geo\": {")
  end

  it "handles a bare array document" do
    array_document = described_class.new([1, 2])

    expect(array_document.lines.map(&:text)).to eq(["[", "  1,", "  2", "]"])
    expect(array_document.lines[1].path).to eq("[0]")
    expect(array_document.outline).to be_empty
  end
end
