# frozen_string_literal: true

RSpec.describe Lazycouchbase::SoftWrap do
  it "returns short lines untouched" do
    expect(described_class.wrap("  \"abv\": 5.2,", 40)).to eq(["  \"abv\": 5.2,"])
  end

  it "wraps at spaces and indents continuations past the original indent" do
    segments = described_class.wrap("  \"description\": \"Rich golden hue color with floral hop\",", 30)

    expect(segments.first.length).to be <= 30
    expect(segments[1..]).to all(start_with("      "))
    expect(segments.join(" ").squeeze(" ")).to include("floral hop")
  end

  it "hard-breaks a line with no spaces" do
    segments = described_class.wrap("a" * 50, 20)

    expect(segments.first.length).to eq(20)
    expect(segments.join.delete(" ")).to eq("a" * 50)
  end

  it "gives up rather than wrap into a sliver" do
    deep = "#{" " * 30}tail"

    expect(described_class.wrap(deep, 20)).to eq([deep])
  end

  it "loses no characters when wrapping" do
    text = "  \"description\": \"#{"word " * 40}end\","

    segments = described_class.wrap(text, 40)

    expect(segments).to all(satisfy { |segment| segment.length <= 40 })
    expect(segments.join(" ").squeeze(" ")).to eq(text.squeeze(" "))
  end
end
