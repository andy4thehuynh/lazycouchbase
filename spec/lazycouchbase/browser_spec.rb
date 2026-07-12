# frozen_string_literal: true

require "tmpdir"

RSpec.describe Lazycouchbase::Browser do
  def with_path(dir)
    original = ENV.fetch("PATH", "")
    ENV["PATH"] = dir
    yield
  ensure
    ENV["PATH"] = original
  end

  it "opens the url with the first opener found on PATH" do
    Dir.mktmpdir do |dir|
      log = File.join(dir, "opened.log")
      opener = File.join(dir, "xdg-open")
      File.write(opener, "#!/bin/sh\necho \"$1\" > \"#{log}\"\n")
      File.chmod(0o755, opener)

      opened = with_path(dir) { described_class.open("https://example.test/docs") }

      expect(opened).to be(true)
      100.times { File.exist?(log) ? break : sleep(0.01) }
      expect(File.read(log).strip).to eq("https://example.test/docs")
    end
  end

  it "returns false when no opener is on PATH" do
    Dir.mktmpdir do |dir|
      expect(with_path(dir) { described_class.open("https://example.test") }).to be(false)
    end
  end
end
