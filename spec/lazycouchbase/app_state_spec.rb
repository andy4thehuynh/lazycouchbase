# frozen_string_literal: true

RSpec.describe Lazycouchbase::AppState do
  subject(:state) { described_class.new }

  describe "initial state" do
    it "starts in normal mode with the buckets pane focused" do
      expect(state.mode).to eq(:normal)
      expect(state.focused_pane).to eq(:buckets)
    end

    it "starts with empty lists and an empty query" do
      expect(state.buckets).to be_empty
      expect(state.collections).to be_empty
      expect(state.documents).to be_empty
      expect(state.query_text).to eq("")
    end
  end

  describe "#switch_mode" do
    it "changes the mode" do
      state.switch_mode(:help)

      expect(state.mode).to eq(:help)
    end

    it "rejects unknown modes" do
      expect { state.switch_mode(:bogus) }.to raise_error(ArgumentError)
    end
  end

  describe "focus" do
    it "cycles forward through panes and wraps" do
      state.focus_next
      expect(state.focused_pane).to eq(:collections)

      state.focus_next
      expect(state.focused_pane).to eq(:documents)

      state.focus_next
      expect(state.focused_pane).to eq(:buckets)
    end

    it "cycles backward and wraps" do
      state.focus_previous

      expect(state.focused_pane).to eq(:documents)
    end

    it "rejects unknown panes" do
      expect { state.focus(:sidebar) }.to raise_error(ArgumentError)
    end
  end

  describe "list assignment" do
    it "resets downstream selections when buckets change" do
      state.collections = %w[a.b]
      state.documents = %w[doc-1]

      state.buckets = %w[beer-sample]

      expect(state.collections).to be_empty
      expect(state.documents).to be_empty
      expect(state.bucket_index).to eq(0)
    end

    it "resets documents when collections change" do
      state.documents = %w[doc-1 doc-2]

      state.collections = %w[inventory.airline]

      expect(state.documents).to be_empty
      expect(state.collection_index).to eq(0)
    end
  end

  describe "#move_selection" do
    before { state.buckets = %w[alpha beta gamma] }

    it "moves within bounds and reports a change" do
      expect(state.move_selection(1)).to be_truthy
      expect(state.selected_bucket).to eq("beta")
    end

    it "clamps at the end of the list" do
      state.move_selection(10)

      expect(state.selected_bucket).to eq("gamma")
      expect(state.move_selection(1)).to be_nil
    end

    it "clamps at the start of the list" do
      expect(state.move_selection(-1)).to be_nil
      expect(state.selected_bucket).to eq("alpha")
    end

    it "is a no-op for an empty pane" do
      state.focus(:documents)

      expect(state.move_selection(1)).to be_nil
    end

    it "moves the focused pane's selection only" do
      state.collections = %w[a.b c.d]
      state.focus(:collections)

      state.move_selection(1)

      expect(state.collection_index).to eq(1)
      expect(state.bucket_index).to eq(0)
    end
  end

  describe "filtering" do
    before { state.buckets = %w[beer-sample gamesim-sample travel-sample] }

    it "starts with an empty query matching everything" do
      state.start_filter

      expect(state.mode).to eq(:filter)
      expect(state.filter_text).to eq("")
      expect(state.filter_matches).to eq(%w[beer-sample gamesim-sample travel-sample])
    end

    it "narrows matches to the focused pane's list" do
      state.start_filter
      state.filter_text = "g"

      expect(state.filter_matches).to eq(%w[gamesim-sample])
    end

    it "resets the highlight when the query changes" do
      state.start_filter
      state.move_filter_selection(2)

      state.filter_text = "sample"

      expect(state.filter_index).to eq(0)
    end

    it "clamps the highlight within the matches" do
      state.start_filter
      state.filter_text = "sample"

      state.move_filter_selection(10)
      expect(state.filter_index).to eq(2)

      state.move_filter_selection(-10)
      expect(state.filter_index).to eq(0)
    end

    it "commits the highlighted match as the pane selection" do
      state.start_filter
      state.filter_text = "g"

      expect(state.commit_filter).to be(true)
      expect(state.mode).to eq(:normal)
      expect(state.selected_bucket).to eq("gamesim-sample")
      expect(state.filter_text).to eq("")
    end

    it "reports no change when committing the current selection" do
      state.start_filter
      state.filter_text = "beer"

      expect(state.commit_filter).to be(false)
      expect(state.selected_bucket).to eq("beer-sample")
    end

    it "degrades commit to a cancel when nothing matches" do
      state.move_selection(1)
      state.start_filter
      state.filter_text = "zzz"

      expect(state.commit_filter).to be(false)
      expect(state.mode).to eq(:normal)
      expect(state.selected_bucket).to eq("gamesim-sample")
    end

    it "cancels without touching the selection" do
      state.move_selection(2)
      state.start_filter
      state.filter_text = "beer"

      state.cancel_filter

      expect(state.mode).to eq(:normal)
      expect(state.selected_bucket).to eq("travel-sample")
      expect(state.filter_text).to eq("")
    end

    it "filters the focused pane only" do
      state.collections = %w[inventory.airline inventory.route]
      state.focus(:collections)
      state.start_filter
      state.filter_text = "route"

      expect(state.commit_filter).to be(true)
      expect(state.selected_collection).to eq("inventory.route")
      expect(state.bucket_index).to eq(0)
    end
  end

  describe "#select_edge" do
    before { state.buckets = %w[alpha beta gamma] }

    it "jumps to the last item" do
      state.select_edge(:last)

      expect(state.selected_bucket).to eq("gamma")
    end

    it "jumps back to the first item" do
      state.select_edge(:last)
      state.select_edge(:first)

      expect(state.selected_bucket).to eq("alpha")
    end
  end

  describe "#select_bucket" do
    before { state.buckets = %w[alpha beta] }

    it "selects a bucket by name" do
      expect(state.select_bucket("beta")).to be_truthy
      expect(state.selected_bucket).to eq("beta")
    end

    it "keeps the selection when the name is unknown" do
      expect(state.select_bucket("nope")).to be_nil
      expect(state.selected_bucket).to eq("alpha")
    end
  end

  describe "#document_scroll=" do
    it "clamps to the document's line count before the view reports a height" do
      state.document_body = "line 1\nline 2\nline 3\n"

      state.document_scroll = 99
      expect(state.document_scroll).to eq(2)

      state.document_scroll = -5
      expect(state.document_scroll).to eq(0)
    end

    it "stops once the last page is visible when the view height is known" do
      state.document_body = Array.new(40) { |line| "line #{line}" }.join("\n")
      state.document_view_height = 25

      state.document_scroll = 99

      expect(state.document_scroll).to eq(15)
    end

    it "does not scroll a document shorter than the view" do
      state.document_body = "one line"
      state.document_view_height = 25

      state.document_scroll = 5

      expect(state.document_scroll).to eq(0)
    end
  end

  describe "#document_body=" do
    it "caches the line count" do
      state.document_body = "a\nb\nc"

      expect(state.document_line_count).to eq(3)
    end
  end

  describe "status" do
    it "records info messages" do
      state.info("connected")

      expect(state.status_message).to eq("connected")
      expect(state.status_kind).to eq(:info)
    end

    it "records error messages" do
      state.error("boom")

      expect(state.status_message).to eq("boom")
      expect(state.status_kind).to eq(:error)
    end
  end
end
