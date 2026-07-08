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
    it "clamps to the document's line count" do
      state.document_body = "line 1\nline 2\nline 3\n"

      state.document_scroll = 99
      expect(state.document_scroll).to eq(2)

      state.document_scroll = -5
      expect(state.document_scroll).to eq(0)
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
