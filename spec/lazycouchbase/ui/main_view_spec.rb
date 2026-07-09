# frozen_string_literal: true

RSpec.describe Lazycouchbase::UI::MainView, :tui do
  let(:view) { described_class.new }
  let(:state) do
    Lazycouchbase::AppState.new.tap do |s|
      s.buckets = %w[beer-sample travel-sample]
      s.collections = [
        Lazycouchbase::Client::CollectionRef.new(scope: "_default", collection: "_default"),
        Lazycouchbase::Client::CollectionRef.new(scope: "inventory", collection: "airline")
      ]
      s.documents = %w[airline_10 airline_112]
      s.connection_label = "localhost"
      s.info("Connected")
    end
  end

  def rendered(width: 100, height: 30)
    screen = nil
    with_test_terminal(width, height) do
      RatatuiRuby.run do |tui|
        tui.draw { |frame| view.render(tui, frame, state) }
        screen = buffer_content.join("\n")
      end
    end
    screen
  end

  it "renders the three panes with counts" do
    screen = rendered

    expect(screen).to include("[1] Buckets (2)")
    expect(screen).to include("[2] Collections (2)")
    expect(screen).to include("[3] Documents (2)")
  end

  it "renders bucket, collection, and document entries" do
    screen = rendered

    expect(screen).to include("beer-sample")
    expect(screen).to include("inventory.airline")
    expect(screen).to include("airline_112")
  end

  it "marks the selected row in the focused pane" do
    screen = rendered

    expect(screen).to match(/❯ beer-sample/)
  end

  it "highlights the selected row with reverse video" do
    with_test_terminal(100, 30) do
      RatatuiRuby.run do |tui|
        tui.draw { |frame| view.render(tui, frame, state) }

        row = buffer_content.index { |line| line.include?("❯ beer-sample") }
        column = buffer_content[row].index("beer-sample")
        modifiers = (get_cell(column, row).modifiers || []).map(&:to_sym)

        expect(modifiers).to include(:reversed)
      end
    end
  end

  it "renders the filter query and match count while filtering" do
    state.start_filter
    state.filter_text = "t"

    screen = rendered

    expect(screen).to include("[1] Buckets (1/2) /t█")
    expect(screen).to include("travel-sample")
    expect(screen).not_to include("beer-sample")
  end

  it "renders the status bar message and hints" do
    screen = rendered

    expect(screen).to include("Connected")
    expect(screen).to include("q: quit")
    expect(screen).to include("localhost")
  end

  it "renders the document view in document mode" do
    state.show_document("airline_10", { "name" => "40-Mile Air" })

    screen = rendered

    expect(screen).to include("Document: airline_10")
    expect(screen).to include("40-Mile Air")
    expect(screen).not_to include("[3] Documents")
  end

  it "shows a breadcrumb for the cursor position in the status bar" do
    state.show_document("airline_10", { "geo" => { "lat" => 48.5 } })
    state.doc.move_cursor(2)

    screen = rendered(width: 140)

    expect(screen).to include("beer-sample › _default._default › airline_10 › geo.lat")
  end

  it "soft-wraps long values instead of clipping them" do
    state.show_document("airline_10", { "description" => "#{"lorem ipsum " * 20}TAIL" })

    screen = rendered

    expect(screen).to include("TAIL")
  end

  it "preserves JSON indentation in the document view" do
    state.show_document("airport_1256", { "geo" => { "lat" => 48.596219 } })

    screen = rendered

    expect(screen).to include('  "geo": {')
    expect(screen).to include('    "lat": 48.596219')
  end

  it "renders the query editor and results in query mode" do
    state.switch_mode(:query)
    state.query_text = "SELECT 1"
    state.query_rows = ['{"answer":42}']
    state.query_status = "success in 5ms"

    screen = rendered

    expect(screen).to include("N1QL Query")
    expect(screen).to include("SELECT 1█")
    expect(screen).to include("Results (1) — success in 5ms")
    expect(screen).to include('{"answer":42}')
  end

  it "renders the help screen in help mode" do
    state.switch_mode(:help)

    screen = rendered

    expect(screen).to include("Help")
    expect(screen).to include("cycle panes")
    expect(screen).not_to include("[1] Buckets")
  end

  it "renders empty panes without a selection marker" do
    empty = Lazycouchbase::AppState.new
    empty_view = described_class.new

    screen = nil
    with_test_terminal(100, 30) do
      RatatuiRuby.run do |tui|
        tui.draw { |frame| empty_view.render(tui, frame, empty) }
        screen = buffer_content.join("\n")
      end
    end

    expect(screen).to include("[1] Buckets (0)")
    expect(screen).not_to include("❯")
  end
end
