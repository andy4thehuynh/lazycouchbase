# frozen_string_literal: true

require "ratatui_ruby"

RSpec.describe Lazycouchbase::KeyHandler do
  subject(:handler) { described_class.new(state) }

  let(:state) { Lazycouchbase::AppState.new }

  def key(code, modifiers: [])
    RatatuiRuby::Event::Key.new(code: code, modifiers: modifiers)
  end

  before do
    state.buckets = %w[beer-sample travel-sample]
    state.collections = [
      Lazycouchbase::Client::CollectionRef.new(scope: "_default", collection: "_default"),
      Lazycouchbase::Client::CollectionRef.new(scope: "inventory", collection: "airline")
    ]
    state.documents = %w[doc-1 doc-2]
  end

  it "ignores non-key events" do
    expect(handler.call(RatatuiRuby::Event::Resize.new(width: 80, height: 24))).to be_nil
  end

  it "quits on ctrl-c in any mode" do
    state.switch_mode(:query)

    expect(handler.call(key("c", modifiers: ["ctrl"]))).to eq(:quit)
  end

  describe "normal mode" do
    it "quits on q" do
      expect(handler.call(key("q"))).to eq(:quit)
    end

    it "refreshes on r" do
      expect(handler.call(key("r"))).to eq(:refresh)
    end

    it "opens help on ?" do
      expect(handler.call(key("?"))).to be_nil
      expect(state.mode).to eq(:help)
    end

    it "opens the query editor on :" do
      handler.call(key(":"))

      expect(state.mode).to eq(:query)
    end

    it "cycles panes with tab and back_tab" do
      handler.call(key("tab"))
      expect(state.focused_pane).to eq(:collections)

      handler.call(key("back_tab"))
      expect(state.focused_pane).to eq(:buckets)
    end

    it "jumps to panes with number keys" do
      handler.call(key("3"))

      expect(state.focused_pane).to eq(:documents)
    end

    it "requests collections when the bucket selection moves" do
      expect(handler.call(key("j"))).to eq(:load_collections)
      expect(state.selected_bucket).to eq("travel-sample")
    end

    it "requests documents when the collection selection moves" do
      state.focus(:collections)

      expect(handler.call(key("down"))).to eq(:load_documents)
    end

    it "returns no action when the selection cannot move" do
      expect(handler.call(key("k"))).to be_nil
    end

    it "moves the document selection without reloading" do
      state.focus(:documents)

      expect(handler.call(key("j"))).to be_nil
      expect(state.selected_document).to eq("doc-2")
    end

    it "jumps to the edges with g and G" do
      expect(handler.call(key("G", modifiers: ["shift"]))).to eq(:load_collections)
      expect(state.selected_bucket).to eq("travel-sample")

      expect(handler.call(key("g"))).to eq(:load_collections)
      expect(state.selected_bucket).to eq("beer-sample")
    end

    it "drills into the next pane on enter" do
      handler.call(key("enter"))
      expect(state.focused_pane).to eq(:collections)

      handler.call(key("enter"))
      expect(state.focused_pane).to eq(:documents)
    end

    it "opens the selected document on enter in the documents pane" do
      state.focus(:documents)

      expect(handler.call(key("enter"))).to eq(:open_document)
    end

    it "does not open a document when the pane is empty" do
      state.documents = []
      state.focus(:documents)

      expect(handler.call(key("enter"))).to be_falsey
    end
  end

  describe "query mode" do
    before { state.switch_mode(:query) }

    it "appends printable characters" do
      "SELECT 1".chars.each { |char| handler.call(key(char)) }

      expect(state.query_text).to eq("SELECT 1")
    end

    it "appends shifted characters like *" do
      handler.call(key("*", modifiers: ["shift"]))

      expect(state.query_text).to eq("*")
    end

    it "ignores ctrl chords and navigation keys" do
      handler.call(key("a", modifiers: ["ctrl"]))
      handler.call(key("down"))

      expect(state.query_text).to eq("")
    end

    it "deletes with backspace" do
      state.query_text = "SELECT"

      handler.call(key("backspace"))

      expect(state.query_text).to eq("SELEC")
    end

    it "runs the query on enter" do
      state.query_text = "SELECT 1"

      expect(handler.call(key("enter"))).to eq(:run_query)
    end

    it "does not run a blank query" do
      state.query_text = "   "

      expect(handler.call(key("enter"))).to be_nil
    end

    it "returns to normal mode on esc" do
      handler.call(key("esc"))

      expect(state.mode).to eq(:normal)
    end
  end

  describe "document mode" do
    before do
      state.switch_mode(:document)
      state.document_body = Array.new(40) { |line| "line #{line}" }.join("\n")
    end

    it "scrolls with j/k and page keys" do
      handler.call(key("j"))
      handler.call(key("j"))
      handler.call(key("k"))
      expect(state.document_scroll).to eq(1)

      handler.call(key("page_down"))
      expect(state.document_scroll).to eq(11)

      handler.call(key("page_up"))
      expect(state.document_scroll).to eq(1)
    end

    it "jumps to the top and bottom with g and G" do
      handler.call(key("G", modifiers: ["shift"]))
      expect(state.document_scroll).to eq(39)

      handler.call(key("g"))
      expect(state.document_scroll).to eq(0)
    end

    it "leaves the last page visible when G jumps to the bottom" do
      state.document_view_height = 25

      handler.call(key("G", modifiers: ["shift"]))

      expect(state.document_scroll).to eq(15)
    end

    it "returns to normal mode on esc" do
      handler.call(key("esc"))

      expect(state.mode).to eq(:normal)
    end
  end

  describe "help mode" do
    before { state.switch_mode(:help) }

    it "closes on q" do
      handler.call(key("q"))

      expect(state.mode).to eq(:normal)
    end

    it "ignores other keys" do
      handler.call(key("j"))

      expect(state.mode).to eq(:help)
    end
  end
end
