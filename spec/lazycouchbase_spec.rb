# frozen_string_literal: true

RSpec.describe Lazycouchbase do
  describe "module" do
    it "is defined as a module" do
      expect(described_class).to be_a(Module)
    end

    it "has a version number" do
      expect(Lazycouchbase::VERSION).not_to be_nil
    end

    it "has version 0.1.0" do
      expect(Lazycouchbase::VERSION).to eq("0.1.0")
    end
  end

  describe "Zeitwerk loader" do
    it "has a loader configured" do
      expect(described_class.loader).to be_a(Zeitwerk::Loader)
    end

    it "responds to eager_load!" do
      expect(described_class).to respond_to(:eager_load!)
    end
  end

  describe "Error class" do
    it "is defined" do
      expect(defined?(Lazycouchbase::Error)).to eq("constant")
    end

    it "inherits from StandardError" do
      expect(Lazycouchbase::Error.superclass).to eq(StandardError)
    end
  end
end
