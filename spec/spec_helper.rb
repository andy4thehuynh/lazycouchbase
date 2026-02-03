# frozen_string_literal: true

require "lazycouchbase"
require "factory_bot"

# Load support files
Dir[File.join(__dir__, "support", "**", "*.rb")].each { |f| require f }

# Load factories
Dir[File.join(__dir__, "factories", "**", "*.rb")].each { |f| require f }

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # FactoryBot integration
  config.include FactoryBot::Syntax::Methods

  # Run specs in random order
  config.order = :random

  # Seed global randomization with a specific seed for reproducibility
  Kernel.srand config.seed
end
