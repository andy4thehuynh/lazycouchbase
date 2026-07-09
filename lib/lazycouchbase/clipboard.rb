# frozen_string_literal: true

module Lazycouchbase
  # Copies text to the system clipboard through the first CLI tool found on
  # PATH. Returns false when none is available so the UI can say why.
  module Clipboard
    TOOLS = [
      %w[wl-copy],
      %w[xclip -selection clipboard],
      %w[xsel --clipboard --input],
      %w[pbcopy]
    ].freeze

    module_function

    def copy(text)
      tool = available_tool
      return false unless tool

      IO.popen(tool, "w") { |io| io.write(text) }
      true
    rescue SystemCallError
      false
    end

    def available_tool
      TOOLS.find { |command| executable?(command.first) }
    end

    def executable?(name)
      ENV.fetch("PATH", "").split(File::PATH_SEPARATOR).any? do |dir|
        File.executable?(File.join(dir, name))
      end
    end
  end
end
