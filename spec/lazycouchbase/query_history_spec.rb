# frozen_string_literal: true

RSpec.describe Lazycouchbase::QueryHistory do
  subject(:history) { described_class.new }

  describe "#record" do
    it "keeps entries in execution order" do
      history.record("SELECT 1")
      history.record("SELECT 2")

      expect(history.entries).to eq(["SELECT 1", "SELECT 2"])
    end

    it "collapses consecutive duplicates" do
      history.record("SELECT 1")
      history.record("SELECT 1")

      expect(history.entries).to eq(["SELECT 1"])
    end

    it "ignores blank queries" do
      history.record("   ")

      expect(history.entries).to be_empty
    end

    it "caps at #{described_class::LIMIT} entries" do
      35.times { |n| history.record("SELECT #{n}") }

      expect(history.entries.size).to eq(described_class::LIMIT)
      expect(history.entries.first).to eq("SELECT 5")
      expect(history.entries.last).to eq("SELECT 34")
    end
  end

  describe "recall" do
    before do
      history.record("SELECT 1")
      history.record("SELECT 2")
      history.record("SELECT 3")
    end

    it "walks backward from the newest and stays on the oldest" do
      expect(history.recall_previous).to eq("SELECT 3")
      expect(history.recall_previous).to eq("SELECT 2")
      expect(history.recall_previous).to eq("SELECT 1")
      expect(history.recall_previous).to eq("SELECT 1")
    end

    it "walks forward and returns to a blank prompt past the newest" do
      2.times { history.recall_previous }

      expect(history.recall_next).to eq("SELECT 3")
      expect(history.recall_next).to eq("")
    end

    it "returns nil going forward when no recall is in progress" do
      expect(history.recall_next).to be_nil
    end

    it "returns nil going backward with no history" do
      expect(described_class.new.recall_previous).to be_nil
    end

    it "restarts from the newest after a reset" do
      2.times { history.recall_previous }

      history.reset_position

      expect(history.recall_previous).to eq("SELECT 3")
    end

    it "restarts from the newest after recording" do
      history.recall_previous

      history.record("SELECT 4")

      expect(history.recall_previous).to eq("SELECT 4")
    end
  end

  describe "persistence" do
    it "round-trips entries through the JSONL file" do
      with_temp_config_dirs do |_config_dir, data_dir|
        path = File.join(data_dir, "lazycouchbase", "history.jsonl")

        described_class.new(path).record("SELECT 1")
        described_class.new(path).record("SELECT 2")

        expect(described_class.new(path).entries).to eq(["SELECT 1", "SELECT 2"])
      end
    end

    it "starts fresh from a corrupt file" do
      with_temp_config_dirs do |_config_dir, data_dir|
        path = create_data_file(data_dir, "history.jsonl", "not json {{{\n")

        expect(described_class.new(path).entries).to eq([])
      end
    end

    it "resolves the default path from XDG_DATA_HOME" do
      with_temp_config_dirs do |_config_dir, data_dir|
        expect(described_class.default_path).to eq(File.join(data_dir, "lazycouchbase", "history.jsonl"))
      end
    end
  end
end
