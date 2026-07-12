# frozen_string_literal: true

module Lazycouchbase
  # Opens a URL through the first browser opener found on PATH, detached so
  # the TUI keeps the terminal. Returns false when none is available so the
  # caller can fall back to the clipboard.
  module Browser
    OPENERS = %w[xdg-open open].freeze

    module_function

    def open(url)
      opener = OPENERS.find { |name| executable?(name) }
      return false unless opener

      pid = Process.spawn(opener, url, %i[out err] => File::NULL)
      Process.detach(pid)
      true
    rescue SystemCallError
      false
    end

    def executable?(name)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
        File.executable?(File.join(dir, name))
      end
    end
  end
end
