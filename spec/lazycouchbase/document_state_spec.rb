# frozen_string_literal: true

RSpec.describe Lazycouchbase::DocumentState do
  subject(:doc) { described_class.new }

  let(:content) do
    {
      "name" => "Amendment Pale Ale",
      "geo" => { "lat" => 48.596219, "lon" => 3.006786 },
      "description" => "Rich golden hue color with floral hop and sweet malt aroma all around"
    }
  end

  before { doc.load("pale_ale", content) }

  describe "loading" do
    it "exposes the pretty-printed body and id" do
      expect(doc.id).to eq("pale_ale")
      expect(doc.body).to include("  \"geo\": {")
      expect(doc.body).to include("    \"lat\": 48.596219,")
    end

    it "falls back to plain text lines for non-JSON content" do
      doc.load("blob", "line one\nline two")

      expect(doc.body).to eq("line one\nline two")
      expect(doc.outline_entries).to be_empty
    end

    it "resets the cursor and scroll" do
      doc.move_cursor(3)

      doc.load("other", content)

      expect(doc.cursor).to eq(0)
      expect(doc.scroll).to eq(0)
    end
  end

  describe "soft wrapping" do
    it "wraps long lines to the view width" do
      unwrapped = doc.line_count

      doc.view_width = 40

      expect(doc.line_count).to be > unwrapped
      expect(doc.visual_lines.map(&:text)).to all(satisfy { |text| text.length <= 40 })
    end

    it "keeps the logical line's path on wrapped segments" do
      doc.view_width = 40

      continuation = doc.visual_lines.each_index.select do |index|
        doc.visual_lines[index].text.include?("floral")
      end.first
      doc.move_cursor(continuation)

      expect(doc.path).to eq("description")
    end
  end

  describe "cursor" do
    it "clamps to the document bounds" do
      doc.move_cursor(-5)
      expect(doc.cursor).to eq(0)

      doc.move_cursor(100)
      expect(doc.cursor).to eq(doc.line_count - 1)
    end

    it "drags the scroll to keep itself visible" do
      doc.view_height = 3

      doc.move_cursor(5)
      expect(doc.scroll).to eq(3)

      doc.cursor_edge(:first)
      expect(doc.scroll).to eq(0)
    end

    it "reports the path under the cursor" do
      doc.move_cursor(3)

      expect(doc.path).to eq("geo.lat")
    end
  end

  describe "#yank_value" do
    it "returns strings raw" do
      doc.move_cursor(1)

      expect(doc.yank_value).to eq(["name", "Amendment Pale Ale"])
    end

    it "returns scalars as JSON" do
      doc.move_cursor(3)

      expect(doc.yank_value).to eq(["geo.lat", "48.596219"])
    end

    it "pretty-prints containers" do
      doc.move_cursor(2)

      path, text = doc.yank_value
      expect(path).to eq("geo")
      expect(text).to eq(JSON.pretty_generate(content["geo"]))
    end
  end

  describe "search" do
    it "jumps to the first fuzzy match as the query grows" do
      doc.start_search
      doc.search_text = "lon"

      expect(doc.visual_lines[doc.cursor].text).to include("\"lon\"")
    end

    it "stays at the origin when nothing matches" do
      doc.move_cursor(2)
      doc.start_search
      doc.search_text = "zzz"

      expect(doc.cursor).to eq(2)
    end

    it "restores the origin on cancel" do
      doc.move_cursor(2)
      doc.start_search
      doc.search_text = "name"

      doc.cancel_search

      expect(doc.cursor).to eq(2)
      expect(doc.search_text).to eq("")
    end

    it "cycles matches with next_match, wrapping around" do
      doc.start_search
      doc.search_text = "o"
      first = doc.cursor

      doc.next_match(1)
      expect(doc.cursor).to be > first

      doc.next_match(-1)
      expect(doc.cursor).to eq(first)

      doc.next_match(-1)
      expect(doc.cursor).to be > first
    end
  end

  describe "outline" do
    it "lists the document's keys" do
      expect(doc.outline_entries.map(&:text)).to eq(["name", "geo", "  lat", "  lon", "description"])
    end

    it "toggles only when there are keys" do
      expect(doc.outline_available?).to be(true)
      doc.toggle_outline
      expect(doc.outline?).to be(true)

      doc.load("blob", "plain text")
      expect(doc.outline_available?).to be(false)
      doc.toggle_outline
      expect(doc.outline?).to be(false)
    end

    it "jumps the cursor to the committed key" do
      doc.toggle_outline
      doc.move_outline_selection(2)

      doc.commit_outline_selection

      expect(doc.outline?).to be(false)
      expect(doc.visual_lines[doc.cursor].text).to include("\"lat\"")
    end

    it "clamps the outline selection" do
      doc.toggle_outline

      doc.move_outline_selection(10)

      expect(doc.outline_index).to eq(4)
    end
  end
end
