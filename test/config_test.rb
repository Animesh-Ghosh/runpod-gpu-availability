# frozen_string_literal: true

require_relative 'test_helper'

class ConfigTest < Minitest::Test
  def test_reads_the_api_key_and_database_path
    config = RunpodGpuAvailability::Config.load('RUNPOD_API_KEY' => 'test-key', 'DATABASE_PATH' => 'tmp/test.sqlite3')

    assert_equal 'test-key', config.api_key
    assert_equal 'tmp/test.sqlite3', config.database_path
  end
end
