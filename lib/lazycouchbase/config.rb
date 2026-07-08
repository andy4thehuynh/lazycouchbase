# frozen_string_literal: true

require "toml-rb"

module Lazycouchbase
  # Merged application configuration.
  #
  # Settings are resolved with the following precedence, lowest to highest:
  # built-in defaults, the TOML file at
  # +$XDG_CONFIG_HOME/lazycouchbase/config.toml+, +LAZYCOUCHBASE_*+
  # environment variables, and explicit overrides (typically CLI flags).
  class Config
    Connection = Data.define(:host, :username, :password, :bucket)

    DEFAULT_HOST = "localhost"
    DEFAULT_USERNAME = "Administrator"
    DEFAULT_PASSWORD = "password"
    DEFAULT_DOCUMENT_LIMIT = 50

    class << self
      def load(overrides = {}, path: nil)
        path ||= default_path
        new(file_data: read_file(path), overrides: overrides, path: path)
      end

      def default_path
        base = ENV.fetch("XDG_CONFIG_HOME") { File.join(Dir.home, ".config") }
        File.join(base, "lazycouchbase", "config.toml")
      end

      private

      def read_file(path)
        return {} unless File.file?(path)

        TomlRB.load_file(path)
      rescue TomlRB::ParseError => e
        raise Error, "Invalid config file #{path}: #{e.message}"
      end
    end

    attr_reader :path

    def initialize(file_data: {}, overrides: {}, path: nil)
      @file_data = file_data
      @overrides = overrides.compact.transform_keys(&:to_s)
      @path = path
    end

    def connection
      Connection.new(
        host: setting("host") || DEFAULT_HOST,
        username: setting("username") || DEFAULT_USERNAME,
        password: setting("password") || DEFAULT_PASSWORD,
        bucket: setting("bucket")
      )
    end

    def document_limit
      value = @overrides["document_limit"] || section("ui")["document_limit"]
      return DEFAULT_DOCUMENT_LIMIT if value.nil?

      Integer(value)
    rescue ArgumentError, TypeError
      raise Error, "document_limit must be an integer, got #{value.inspect}"
    end

    private

    def setting(key)
      @overrides[key] || ENV.fetch("LAZYCOUCHBASE_#{key.upcase}", nil) || section("connection")[key]
    end

    def section(name)
      value = @file_data[name]
      value.is_a?(Hash) ? value : {}
    end
  end
end
