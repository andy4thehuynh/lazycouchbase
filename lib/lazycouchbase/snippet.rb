# frozen_string_literal: true

module Lazycouchbase
  # A single SQL++ example: a ready-to-run template plus the docs page that
  # explains the concept it demonstrates.
  Snippet = Data.define(:name, :category, :template, :description, :docs) do
    def label
      "#{category} › #{name}"
    end

    # Unfilled placeholders stay visible so the user knows what to edit.
    def statement(keyspace)
      keyspace ? template.gsub("%{keyspace}", keyspace) : template
    end
  end
end
