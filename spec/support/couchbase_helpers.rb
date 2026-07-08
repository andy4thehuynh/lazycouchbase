# frozen_string_literal: true

module CouchbaseHelpers
  COUCHBASE_TEST_HOST = ENV.fetch("COUCHBASE_TEST_HOST", "localhost")
  COUCHBASE_TEST_USERNAME = ENV.fetch("COUCHBASE_TEST_USERNAME", "Administrator")
  COUCHBASE_TEST_PASSWORD = ENV.fetch("COUCHBASE_TEST_PASSWORD", "password")
  COUCHBASE_TEST_BUCKET = ENV.fetch("COUCHBASE_TEST_BUCKET", "default")

  def self.couchbase_available?
    return @couchbase_available if defined?(@couchbase_available)

    @couchbase_available = check_couchbase_connection
  end

  def self.check_couchbase_connection
    require "couchbase"

    options = Couchbase::Options::Cluster.new
    options.authenticate(COUCHBASE_TEST_USERNAME, COUCHBASE_TEST_PASSWORD)

    cluster = Couchbase::Cluster.connect("couchbase://#{COUCHBASE_TEST_HOST}", options)
    cluster.disconnect
    true
  rescue LoadError
    warn "Couchbase gem not available, skipping integration tests"
    false
  rescue StandardError => e
    warn "Couchbase cluster not available: #{e.message}"
    false
  end

  def skip_unless_couchbase
    skip "Couchbase cluster not available" unless CouchbaseHelpers.couchbase_available?
  end

  def test_connection_string
    "couchbase://#{COUCHBASE_TEST_HOST}"
  end

  def test_credentials
    {
      username: COUCHBASE_TEST_USERNAME,
      password: COUCHBASE_TEST_PASSWORD
    }
  end

  def test_bucket_name
    COUCHBASE_TEST_BUCKET
  end

  def with_test_cluster
    skip_unless_couchbase

    require "couchbase"

    options = Couchbase::Options::Cluster.new
    options.authenticate(COUCHBASE_TEST_USERNAME, COUCHBASE_TEST_PASSWORD)

    cluster = Couchbase::Cluster.connect("couchbase://#{COUCHBASE_TEST_HOST}", options)
    yield cluster
  ensure
    cluster&.disconnect
  end
end

RSpec.configure do |config|
  config.include CouchbaseHelpers

  config.before(:suite) do
    reporter = RSpec.configuration.reporter
    if CouchbaseHelpers.couchbase_available?
      reporter.message("Couchbase cluster available at #{CouchbaseHelpers::COUCHBASE_TEST_HOST}")
    else
      reporter.message("Couchbase cluster not available - integration tests will be skipped")
    end
  end
end
