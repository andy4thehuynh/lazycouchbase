# frozen_string_literal: true

# Keep LAZYCOUCHBASE_* variables from leaking between examples (or in from
# the developer's shell): each example starts with them unset and any values
# it sets are discarded afterwards.
RSpec.configure do |config|
  lazycouchbase_keys = %w[LAZYCOUCHBASE_HOST LAZYCOUCHBASE_USERNAME LAZYCOUCHBASE_PASSWORD
                          LAZYCOUCHBASE_BUCKET LAZYCOUCHBASE_DOCUMENT_LIMIT]

  config.around do |example|
    saved = ENV.to_h.slice(*lazycouchbase_keys)
    lazycouchbase_keys.each { |key| ENV.delete(key) }
    example.run
  ensure
    lazycouchbase_keys.each { |key| ENV.delete(key) }
    saved.each { |key, value| ENV[key] = value }
  end
end
