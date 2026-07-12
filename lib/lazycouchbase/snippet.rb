# frozen_string_literal: true

module Lazycouchbase
  # A single SQL++ lesson: an insertable skeleton (template), a runnable
  # travel-sample version of it (example), and the docs page that explains
  # the concept it demonstrates.
  Snippet = Data.define(:name, :category, :template, :example, :description, :docs) do
    def label
      "#{category} › #{name}"
    end

    # Unfilled placeholders stay visible so the user knows what to edit.
    def statement(keyspace)
      keyspace ? template.gsub("%{keyspace}", keyspace) : template
    end
  end
end
