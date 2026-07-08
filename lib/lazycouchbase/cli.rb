# frozen_string_literal: true

require "optparse"
require "ratatui_ruby"

module Lazycouchbase
  # Command-line entry point: parses flags, builds the Config and Client,
  # and starts the App. Returns a process exit status from #run.
  class CLI
    def initialize(argv = ARGV, stdout: $stdout, stderr: $stderr)
      @argv = argv
      @stdout = stdout
      @stderr = stderr
      @halted = false
      @config_path = nil
    end

    def run
      overrides = parse(@argv)
      return 0 if @halted

      start(overrides)
    rescue OptionParser::ParseError => e
      @stderr.puts(e.message)
      @stderr.puts("Run `lazycouchbase --help` for usage.")
      1
    rescue Lazycouchbase::Error => e
      @stderr.puts("Error: #{e.message}")
      1
    rescue RatatuiRuby::Error => e
      @stderr.puts("Terminal error: #{e.message} (lazycouchbase needs an interactive terminal)")
      1
    rescue Interrupt
      130
    end

    private

    def parse(argv)
      overrides = {}
      parser(overrides).parse(argv)
      overrides
    end

    def start(overrides)
      config = Config.load(overrides, path: @config_path)
      App.new(client: Client.new(config.connection), config: config).run
      0
    end

    def parser(overrides)
      OptionParser.new do |opts|
        opts.banner = "Usage: lazycouchbase [options]\n\nA keyboard-driven TUI for Couchbase.\n\nOptions:"
        connection_options(opts, overrides)
        general_options(opts)
      end
    end

    def connection_options(opts, overrides)
      opts.on("-H", "--host HOST", "Couchbase host or connection string (default: localhost)") do |host|
        overrides[:host] = host
      end
      opts.on("-u", "--username USERNAME", "Username (default: Administrator)") { |user| overrides[:username] = user }
      opts.on("-p", "--password PASSWORD", "Password") { |password| overrides[:password] = password }
      opts.on("-b", "--bucket BUCKET", "Bucket to select at startup") { |bucket| overrides[:bucket] = bucket }
    end

    def general_options(opts)
      opts.on("-c", "--config PATH", "Config file (default: #{Config.default_path})") do |path|
        @config_path = path
      end
      opts.on("-v", "--version", "Print the version and exit") do
        @stdout.puts(VERSION)
        @halted = true
      end
      opts.on("-h", "--help", "Print this help and exit") do
        @stdout.puts(opts)
        @halted = true
      end
    end
  end
end
