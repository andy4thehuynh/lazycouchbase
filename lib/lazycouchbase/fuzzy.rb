# frozen_string_literal: true

module Lazycouchbase
  # Case-insensitive subsequence matching in the style of fzf: every query
  # character must appear in the candidate in order, but not necessarily
  # adjacently ("ta2" matches "tenant_agent_02.users").
  module Fuzzy
    module_function

    def match?(query, candidate)
      pattern = query.downcase
      return true if pattern.empty?

      index = 0
      candidate.to_s.downcase.each_char do |char|
        index += 1 if char == pattern[index]
        return true if index == pattern.length
      end
      false
    end
  end
end
