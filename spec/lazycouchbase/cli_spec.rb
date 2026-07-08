# frozen_string_literal: true

RSpec.describe Lazycouchbase::CLI do
  let(:stdout) { StringIO.new }
  let(:stderr) { StringIO.new }

  def cli(*argv)
    described_class.new(argv, stdout: stdout, stderr: stderr)
  end

  describe "--version" do
    it "prints the version and exits successfully" do
      status = cli("--version").run

      expect(status).to eq(0)
      expect(stdout.string).to eq("#{Lazycouchbase::VERSION}\n")
    end
  end

  describe "--help" do
    it "prints usage and exits successfully" do
      status = cli("--help").run

      expect(status).to eq(0)
      expect(stdout.string).to include("Usage: lazycouchbase")
      expect(stdout.string).to include("--host")
      expect(stdout.string).to include("--bucket")
    end
  end

  describe "invalid options" do
    it "prints the parse error and fails" do
      status = cli("--bogus").run

      expect(status).to eq(1)
      expect(stderr.string).to include("invalid option: --bogus")
      expect(stderr.string).to include("--help")
    end
  end

  describe "starting the app" do
    let(:app) { instance_double(Lazycouchbase::App, run: nil) }

    before do
      allow(Lazycouchbase::App).to receive(:new).and_return(app)
    end

    it "builds the client from merged config and runs the app" do
      with_temp_config_dirs do
        status = cli("--host", "db.example.com", "--username", "admin",
                     "--password", "hunter2", "--bucket", "travel-sample").run

        expect(status).to eq(0)
      end

      expect(Lazycouchbase::App).to have_received(:new) do |client:, config:|
        expect(client.connection.host).to eq("db.example.com")
        expect(config.connection.bucket).to eq("travel-sample")
      end
      expect(app).to have_received(:run)
    end

    it "honours --config for the config file location" do
      with_temp_config_dirs do |config_dir, _data_dir|
        path = create_config_file(config_dir, "elsewhere.toml", <<~TOML)
          [connection]
          host = "from-file.example.com"
        TOML

        cli("--config", path).run
      end

      expect(Lazycouchbase::App).to have_received(:new) do |client:, config:|
        expect(client.connection.host).to eq("from-file.example.com")
        expect(config.path).to include("elsewhere.toml")
      end
    end

    it "reports Lazycouchbase errors on stderr and fails" do
      allow(app).to receive(:run).and_raise(Lazycouchbase::Client::Error, "cluster unreachable")

      status = with_temp_config_dirs { cli.run }

      expect(status).to eq(1)
      expect(stderr.string).to include("Error: cluster unreachable")
    end

    it "exits with 130 on interrupt" do
      allow(app).to receive(:run).and_raise(Interrupt)

      status = with_temp_config_dirs { cli.run }

      expect(status).to eq(130)
    end
  end
end
