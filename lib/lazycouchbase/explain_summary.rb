# frozen_string_literal: true

module Lazycouchbase
  # Turns an EXPLAIN plan into short human-readable lines: a headline about
  # index usage, then one line per interesting operator. A deterministic rule
  # table -- unknown operators fall back to their raw names so the summary
  # never hides a step it does not understand.
  class ExplainSummary
    # Plumbing operators that say nothing about how data is read.
    SKIP = %w[Sequence Parallel Authorize Stream Alias InitialProject FinalProject
              IntermediateGroup FinalGroup].freeze

    DESCRIBERS = {
      "PrimaryScan" => ->(op) { "Primary scan on #{op["keyspace"]} — reads every document" },
      "IndexScan" => ->(op) { "Index scan #{op["index"]} on #{op["keyspace"]}" },
      "Fetch" => ->(op) { "Fetch documents from #{op["keyspace"]}" },
      "Filter" => ->(op) { "Filter: #{op["condition"]}" },
      "NestedLoopJoin" => ->(op) { "Nested-loop join on #{op["on_clause"]}" },
      "HashJoin" => ->(op) { "Hash join on #{op["on_clause"]}" },
      "Join" => ->(op) { "Join with #{op["keyspace"]}" },
      "Unnest" => ->(op) { "Unnest #{op["as"] || op["expr"]}" },
      "CountScan" => ->(op) { "Count from index metadata on #{op["keyspace"]} — no documents read" },
      "InitialGroup" => lambda { |op|
        keys = Array(op["group_keys"])
        keys.empty? ? "Aggregate" : "Group by #{keys.join(", ")}"
      },
      "Order" => ->(op) { "Sort by #{Array(op["sort_terms"]).filter_map { |term| term["expr"] }.join(", ")}" },
      "Limit" => ->(op) { "Limit #{op["expr"]}" },
      "Offset" => ->(op) { "Offset #{op["expr"]}" }
    }.freeze

    def initialize(plan)
      @plan = plan
    end

    def lines
      [headline] + steps
    end

    private

    def operators
      @operators ||= collect(@plan)
    end

    def collect(node)
      case node
      when Hash
        own = node.key?("#operator") ? [node] : []
        own + node.values.flat_map { |value| collect(value) }
      when Array then node.flat_map { |value| collect(value) }
      else []
      end
    end

    def headline
      indexes = operators.select { |op| kind(op) == "IndexScan" }.filter_map { |op| op["index"] }.uniq
      return "Uses index#{"es" if indexes.size > 1}: #{indexes.join(", ")}" if indexes.any?
      return "Answered from index metadata — no documents read" if kind?("CountScan")
      return "No index used — primary scan reads the whole keyspace" if kind?("PrimaryScan")

      "No keyspace scan (expression-only query)"
    end

    def kind?(name)
      operators.any? { |op| kind(op) == name }
    end

    def steps
      operators.filter_map { |op| describe(op) }
    end

    def describe(operator)
      name = kind(operator)
      return nil if SKIP.include?(name)

      describer = DESCRIBERS[name]
      describer ? describer.call(operator) : operator["#operator"]
    end

    # The server suffixes operator versions ("IndexScan3"); the rules do not care.
    def kind(operator)
      operator["#operator"].to_s.sub(/\d+\z/, "")
    end
  end
end
