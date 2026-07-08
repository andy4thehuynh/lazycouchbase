# frozen_string_literal: true

require "ratatui_ruby"
require "ratatui_ruby/test_helper"

# Headless-terminal helpers (with_test_terminal, buffer_content, inject_keys)
# for specs tagged with :tui.
RSpec.configure do |config|
  config.include RatatuiRuby::TestHelper, :tui
end
