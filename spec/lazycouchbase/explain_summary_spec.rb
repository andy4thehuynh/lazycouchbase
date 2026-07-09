# frozen_string_literal: true

RSpec.describe Lazycouchbase::ExplainSummary do
  def lines_for(plan)
    described_class.new(plan).lines
  end

  it "headlines a primary scan as a warning" do
    plan = {
      "#operator" => "Sequence",
      "~children" => [
        { "#operator" => "PrimaryScan3", "keyspace" => "beer-sample" },
        { "#operator" => "Fetch", "keyspace" => "beer-sample" }
      ]
    }

    lines = lines_for(plan)

    expect(lines.first).to eq("No index used — primary scan reads the whole keyspace")
    expect(lines).to include("Primary scan on beer-sample — reads every document")
    expect(lines).to include("Fetch documents from beer-sample")
  end

  it "headlines the indexes in use" do
    plan = {
      "#operator" => "Sequence",
      "~children" => [
        { "#operator" => "IndexScan3", "index" => "def_type", "keyspace" => "travel-sample" },
        { "#operator" => "Filter", "condition" => "(`t`.`type` = \"airline\")" }
      ]
    }

    lines = lines_for(plan)

    expect(lines.first).to eq("Uses index: def_type")
    expect(lines).to include("Index scan def_type on travel-sample")
    expect(lines).to include('Filter: (`t`.`type` = "airline")')
  end

  it "describes grouping and ordering" do
    plan = {
      "#operator" => "Sequence",
      "~children" => [
        { "#operator" => "IndexScan3", "index" => "def_city", "keyspace" => "hotels" },
        { "#operator" => "InitialGroup", "group_keys" => ["(`h`.`city`)"] },
        { "#operator" => "FinalGroup", "group_keys" => ["(`h`.`city`)"] },
        { "#operator" => "Order", "sort_terms" => [{ "expr" => "count(*)" }] },
        { "#operator" => "Limit", "expr" => "10" }
      ]
    }

    lines = lines_for(plan)

    expect(lines).to include("Group by (`h`.`city`)")
    expect(lines).to include("Sort by count(*)")
    expect(lines).to include("Limit 10")
    expect(lines.grep(/Group by/).size).to eq(1)
  end

  it "recognizes a count answered from index metadata" do
    plan = {
      "#operator" => "Sequence",
      "~children" => [
        { "#operator" => "CountScan", "keyspace" => "airline" },
        { "#operator" => "InitialGroup", "group_keys" => [] }
      ]
    }

    lines = lines_for(plan)

    expect(lines.first).to eq("Answered from index metadata — no documents read")
    expect(lines).to include("Count from index metadata on airline — no documents read")
    expect(lines).to include("Aggregate")
  end

  it "keeps unknown operators visible by their raw name" do
    plan = { "#operator" => "SomeNewOperator42" }

    expect(lines_for(plan)).to include("SomeNewOperator42")
  end

  it "handles an expression-only plan" do
    plan = { "#operator" => "Sequence", "~children" => [] }

    expect(lines_for(plan).first).to eq("No keyspace scan (expression-only query)")
  end
end
