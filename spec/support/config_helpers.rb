# frozen_string_literal: true

require "fileutils"
require "tmpdir"

module ConfigHelpers
  def with_temp_config_dirs
    Dir.mktmpdir("lazycouchbase-test-config") do |config_dir|
      Dir.mktmpdir("lazycouchbase-test-data") do |data_dir|
        with_xdg_env(config_dir, data_dir) do
          yield config_dir, data_dir
        end
      end
    end
  end

  def with_xdg_env(config_dir, data_dir)
    original_config = ENV.fetch("XDG_CONFIG_HOME", nil)
    original_data = ENV.fetch("XDG_DATA_HOME", nil)

    ENV["XDG_CONFIG_HOME"] = config_dir
    ENV["XDG_DATA_HOME"] = data_dir

    yield
  ensure
    if original_config
      ENV["XDG_CONFIG_HOME"] = original_config
    else
      ENV.delete("XDG_CONFIG_HOME")
    end

    if original_data
      ENV["XDG_DATA_HOME"] = original_data
    else
      ENV.delete("XDG_DATA_HOME")
    end
  end

  def create_config_file(config_dir, filename, content)
    app_config_dir = File.join(config_dir, "lazycouchbase")
    FileUtils.mkdir_p(app_config_dir)
    file_path = File.join(app_config_dir, filename)
    File.write(file_path, content)
    file_path
  end

  def create_data_file(data_dir, filename, content)
    app_data_dir = File.join(data_dir, "lazycouchbase")
    FileUtils.mkdir_p(app_data_dir)
    file_path = File.join(app_data_dir, filename)
    File.write(file_path, content)
    file_path
  end
end

RSpec.configure do |config|
  config.include ConfigHelpers
end
