# frozen_string_literal: true

RSpec.describe Lazycouchbase::Config do
  describe ".default_path" do
    it "lives under XDG_CONFIG_HOME when set" do
      with_temp_config_dirs do |config_dir, _data_dir|
        expect(described_class.default_path).to eq(File.join(config_dir, "lazycouchbase", "config.toml"))
      end
    end

    it "falls back to ~/.config when XDG_CONFIG_HOME is unset" do
      original = ENV.delete("XDG_CONFIG_HOME")
      expect(described_class.default_path).to eq(File.join(Dir.home, ".config", "lazycouchbase", "config.toml"))
    ensure
      ENV["XDG_CONFIG_HOME"] = original if original
    end
  end

  describe ".load" do
    it "uses built-in defaults when no config file exists" do
      with_temp_config_dirs do
        connection = described_class.load.connection

        expect(connection.host).to eq("localhost")
        expect(connection.username).to eq("Administrator")
        expect(connection.password).to eq("password")
        expect(connection.bucket).to be_nil
      end
    end

    it "reads connection settings from the config file" do
      with_temp_config_dirs do |config_dir, _data_dir|
        create_config_file(config_dir, "config.toml", <<~TOML)
          [connection]
          host = "db.example.com"
          username = "admin"
          password = "hunter2"
          bucket = "travel-sample"
        TOML

        connection = described_class.load.connection

        expect(connection.host).to eq("db.example.com")
        expect(connection.username).to eq("admin")
        expect(connection.password).to eq("hunter2")
        expect(connection.bucket).to eq("travel-sample")
      end
    end

    it "lets environment variables override the config file" do
      with_temp_config_dirs do |config_dir, _data_dir|
        create_config_file(config_dir, "config.toml", <<~TOML)
          [connection]
          host = "from-file.example.com"
        TOML
        ENV["LAZYCOUCHBASE_HOST"] = "from-env.example.com"

        expect(described_class.load.connection.host).to eq("from-env.example.com")
      end
    end

    it "lets explicit overrides win over environment variables" do
      with_temp_config_dirs do
        ENV["LAZYCOUCHBASE_HOST"] = "from-env.example.com"

        connection = described_class.load({ host: "from-flag.example.com" }).connection

        expect(connection.host).to eq("from-flag.example.com")
      end
    end

    it "ignores nil overrides" do
      with_temp_config_dirs do
        connection = described_class.load({ host: nil, bucket: "beer-sample" }).connection

        expect(connection.host).to eq("localhost")
        expect(connection.bucket).to eq("beer-sample")
      end
    end

    it "loads from an explicit path" do
      with_temp_config_dirs do |config_dir, _data_dir|
        path = create_config_file(config_dir, "custom.toml", <<~TOML)
          [connection]
          host = "custom.example.com"
        TOML

        config = described_class.load(path: path)

        expect(config.connection.host).to eq("custom.example.com")
        expect(config.path).to eq(path)
      end
    end

    it "raises Lazycouchbase::Error for invalid TOML" do
      with_temp_config_dirs do |config_dir, _data_dir|
        create_config_file(config_dir, "config.toml", "connection = [not toml")

        expect { described_class.load }.to raise_error(Lazycouchbase::Error, /Invalid config file/)
      end
    end
  end

  describe "#document_limit" do
    it "defaults to 50" do
      expect(described_class.new.document_limit).to eq(50)
    end

    it "reads the ui section of the config file" do
      config = described_class.new(file_data: { "ui" => { "document_limit" => 100 } })

      expect(config.document_limit).to eq(100)
    end

    it "prefers overrides" do
      config = described_class.new(file_data: { "ui" => { "document_limit" => 100 } },
                                   overrides: { document_limit: 25 })

      expect(config.document_limit).to eq(25)
    end

    it "raises Lazycouchbase::Error when not an integer" do
      config = described_class.new(file_data: { "ui" => { "document_limit" => "plenty" } })

      expect { config.document_limit }.to raise_error(Lazycouchbase::Error, /document_limit/)
    end
  end
end
