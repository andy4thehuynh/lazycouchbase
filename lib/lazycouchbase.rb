# frozen_string_literal: true

require "zeitwerk"

module Lazycouchbase
  class Error < StandardError; end

  class << self
    def loader
      @loader ||= begin
        loader = Zeitwerk::Loader.for_gem
        loader.inflector.inflect(
          "ui" => "UI",
          "tui" => "TUI",
          "cli" => "CLI"
        )
        loader
      end
    end

    def eager_load!
      loader.eager_load
    end
  end
end

Lazycouchbase.loader.setup
