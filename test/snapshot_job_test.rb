# frozen_string_literal: true

require_relative 'test_helper'
require 'sqlite3'

class SnapshotJobTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @path = File.join(@directory, 'availability.sqlite3')
    RunpodGpuAvailability::Migrator.run(path: @path)
  end

  def teardown
    FileUtils.remove_entry @directory
  end

  def test_fails_an_abandoned_capture_before_recording_a_fresh_snapshot
    repository = RunpodGpuAvailability::AvailabilityRepository.new(path: @path)
    abandoned_run_id = repository.start_capture!(product: 'SERVERLESS', started_at: Time.utc(2026, 10, 7))
    repository.close

    client = Struct.new(:catalog) { def fetch = catalog }.new(catalog)

    RunpodGpuAvailability::CatalogClient.stub(:new, client) do
      RunpodGpuAvailability::SnapshotJob.call(config: job_config)
    end

    database = SQLite3::Database.new(@path)
    abandoned_run = database.get_first_row(
      'SELECT status, error_message FROM capture_runs WHERE id = ?',
      abandoned_run_id
    )
    repository = RunpodGpuAvailability::AvailabilityRepository.new(path: @path)
    current_run = repository.latest_capture_run(product: 'SERVERLESS')

    assert_equal 'failed', abandoned_run.fetch(0)
    assert_equal 'collector exited before completing this capture', abandoned_run.fetch(1)
    assert_equal 'succeeded', current_run.fetch('status')
    refute_nil current_run.fetch('snapshot_id')
  ensure
    database&.close
    repository&.close
  end

  private

  def job_config = RunpodGpuAvailability::Config.new(api_key: 'test-key', database_path: @path)

  def catalog
    {
      'gpus' => [{
        'id' => 'NVIDIA GeForce RTX 4090', 'name' => 'RTX 4090', 'pool' => 'ADA_24', 'memory' => 24,
        'price' => { 'serverless' => 1.1 },
        'dataCenters' => [{ 'id' => 'US-IL-1', 'availability' => 'HIGH' }]
      }]
    }
  end
end
