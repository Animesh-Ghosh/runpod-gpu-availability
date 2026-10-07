# frozen_string_literal: true

require_relative 'test_helper'

class CaptureSnapshotTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    path = File.join(@directory, 'availability.sqlite3')
    RunpodGpuAvailability::Migrator.run(path:)
    @repository = RunpodGpuAvailability::AvailabilityRepository.new(path:)
  end

  def teardown
    @repository.close
    FileUtils.remove_entry @directory
  end

  def test_records_a_successful_capture_with_its_snapshot
    client = Struct.new(:catalog) { def fetch = catalog }.new(catalog)

    RunpodGpuAvailability::CaptureSnapshot.new(client:, repository: @repository).call

    run = @repository.latest_capture_run(product: 'SERVERLESS')
    assert_equal 'succeeded', run.fetch('status')
    refute_nil run.fetch('snapshot_id')
    assert_nil run.fetch('error_message')
  end

  def test_records_catalog_failures_without_a_snapshot
    client = Object.new
    client.define_singleton_method(:fetch) { raise RunpodGpuAvailability::CatalogClient::Error, 'catalog unavailable' }

    RunpodGpuAvailability::CaptureSnapshot.new(client:, repository: @repository).call

    run = @repository.latest_capture_run(product: 'SERVERLESS')
    assert_equal 'failed', run.fetch('status')
    assert_equal 'catalog unavailable', run.fetch('error_message')
    assert_nil run.fetch('snapshot_id')
  end

  def test_records_unexpected_failures_before_reraising_them
    client = Struct.new(:catalog) { def fetch = catalog }.new({})

    error = assert_raises(KeyError) do
      RunpodGpuAvailability::CaptureSnapshot.new(client:, repository: @repository).call
    end

    run = @repository.latest_capture_run(product: 'SERVERLESS')
    assert_equal 'failed', run.fetch('status')
    assert_equal error.message, run.fetch('error_message')
    assert_nil run.fetch('snapshot_id')
  end

  private

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
