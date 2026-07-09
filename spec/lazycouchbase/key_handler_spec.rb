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

    it "explains a non-blank query on ctrl-e" do
      state.query_text = "SELECT 1"

      expect(handler.call(key("e", modifiers: ["ctrl"]))).to eq(:explain_query)
    end

    it "does not explain a blank query" do
      expect(handler.call(key("e", modifiers: ["ctrl"]))).to be_nil
    end

    context "with history" do
      before do
        state.query_history = Lazycouchbase::QueryHistory.new
        state.query_history.record("SELECT 1")
        state.query_history.record("SELECT 2")
      end

      it "recalls older queries with the up arrow" do
        handler.call(key("up"))
        expect(state.query_text).to eq("SELECT 2")

        handler.call(key("up"))
        expect(state.query_text).to eq("SELECT 1")
      end

      it "walks forward with the down arrow back to a blank prompt" do
        2.times { handler.call(key("up")) }

        handler.call(key("down"))
        expect(state.query_text).to eq("SELECT 2")

        handler.call(key("down"))
        expect(state.query_text).to eq("")
      end

      it "discards edits when recalling further" do
        handler.call(key("up"))
        handler.call(key("x"))

        handler.call(key("up"))

        expect(state.query_text).to eq("SELECT 1")
      end

      it "resets the recall position when leaving the editor" do
        handler.call(key("up"))
        handler.call(key("esc"))

        state.switch_mode(:query)
        handler.call(key("up"))

        expect(state.query_text).to eq("SELECT 2")
      end
    end

    it "ignores the arrows without history" do
      handler.call(key("up"))

      expect(state.query_text).to eq("")
    end
  end

  describe "filter mode" do
    it "opens the filter for the focused pane on /" do
      handler.call(key("/"))

      expect(state.mode).to eq(:filter)
      expect(state.filter_text).to eq("")
    end

    it "treats printable keys as query text, including q" do
      handler.call(key("/"))
      "qt".chars.each { |char| handler.call(key(char)) }

      expect(state.mode).to eq(:filter)
      expect(state.filter_text).to eq("qt")
    end

    it "ignores ctrl chords and navigation keys" do
      handler.call(key("/"))
      handler.call(key("a", modifiers: ["ctrl"]))
      handler.call(key("tab"))

      expect(state.filter_text).to eq("")
    end

    it "deletes with backspace" do
      handler.call(key("/"))
      handler.call(key("g"))

      handler.call(key("backspace"))

      expect(state.filter_text).to eq("")
    end

    it "moves the highlight with the arrow keys" do
      handler.call(key("/"))

      handler.call(key("down"))
      expect(state.filter_index).to eq(1)

      handler.call(key("up"))
      expect(state.filter_index).to eq(0)
    end

    it "cancels on esc without moving the selection" do
      handler.call(key("/"))
      handler.call(key("t"))

      expect(handler.call(key("esc"))).to be_nil
      expect(state.mode).to eq(:normal)
      expect(state.selected_bucket).to eq("beer-sample")
    end

    it "commits a new bucket on enter and reloads collections" do
      handler.call(key("/"))
      handler.call(key("t"))

      expect(handler.call(key("enter"))).to eq(:load_collections)
      expect(state.mode).to eq(:normal)
      expect(state.selected_bucket).to eq("travel-sample")
    end

    it "returns no action when the selection does not change" do
      handler.call(key("/"))

      expect(handler.call(key("enter"))).to be_nil
      expect(state.selected_bucket).to eq("beer-sample")
    end

    it "commits documents without a reload action" do
      state.focus(:documents)
      handler.call(key("/"))
      handler.call(key("2"))

      expect(handler.call(key("enter"))).to be_nil
      expect(state.selected_document).to eq("doc-2")
    end
  end

  describe "document mode" do
    before do
      state.show_document("beer-1", {
                            "name" => "IPA",
                            "geo" => { "lat" => 1.5, "lon" => 2.5 },
                            "notes" => Array.new(20) { |note| "note #{note}" }
                          })
      state.doc.view_height = 10
    end

    it "moves the cursor with j/k and the scroll follows" do
      12.times { handler.call(key("j")) }
      expect(state.doc.cursor).to eq(12)
      expect(state.doc.scroll).to eq(3)

      handler.call(key("k"))
      expect(state.doc.cursor).to eq(11)
      expect(state.doc.scroll).to eq(3)
    end

    it "jumps to the edges with g and G" do
      handler.call(key("G", modifiers: ["shift"]))
      expect(state.doc.cursor).to eq(state.doc.line_count - 1)
      expect(state.doc.scroll).to eq(state.doc.line_count - 10)

      handler.call(key("g"))
      expect(state.doc.cursor).to eq(0)
      expect(state.doc.scroll).to eq(0)
    end

    it "returns to normal mode on esc" do
      handler.call(key("esc"))

      expect(state.mode).to eq(:normal)
    end

    it "opens the line search on / and jumps as the query grows" do
      handler.call(key("/"))
      expect(state.mode).to eq(:document_search)

      "lon".chars.each { |char| handler.call(key(char)) }

      expect(state.doc.visual_lines[state.doc.cursor].text).to include("\"lon\"")
    end

    it "keeps the match on enter and cycles with n/N" do
      handler.call(key("/"))
      "note".chars.each { |char| handler.call(key(char)) }
      handler.call(key("enter"))
      expect(state.mode).to eq(:document)
      first = state.doc.cursor

      handler.call(key("n"))
      expect(state.doc.cursor).to be > first

      handler.call(key("N", modifiers: ["shift"]))
      expect(state.doc.cursor).to eq(first)
    end

    it "restores the cursor when the search is cancelled" do
      3.times { handler.call(key("j")) }

      handler.call(key("/"))
      handler.call(key("n"))
      handler.call(key("esc"))

      expect(state.mode).to eq(:document)
      expect(state.doc.cursor).to eq(3)
    end

    it "toggles the keys-only outline with t and jumps on enter" do
      handler.call(key("t"))
      expect(state.doc.outline?).to be(true)

      handler.call(key("j"))
      handler.call(key("j"))
      handler.call(key("enter"))

      expect(state.doc.outline?).to be(false)
      expect(state.doc.visual_lines[state.doc.cursor].text).to include("\"lat\"")
    end

    it "refuses the outline for documents without keys" do
      state.show_document("blob", "plain text")

      handler.call(key("t"))

      expect(state.doc.outline?).to be(false)
      expect(state.status_message).to include("No keys")
    end

    it "yanks the document with y and the value with Y" do
      expect(handler.call(key("y"))).to eq(:yank_document)
      expect(handler.call(key("Y", modifiers: ["shift"]))).to eq(:yank_value)
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
