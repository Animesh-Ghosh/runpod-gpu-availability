# frozen_string_literal: true

require_relative 'test_helper'

class AvailabilityRepositoryTest < Minitest::Test
  def test_recovers_abandoned_runs_and_prunes_old_terminal_runs
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'availability.sqlite3')
      RunpodGpuAvailability::Migrator.run(path:)
      repository = RunpodGpuAvailability::AvailabilityRepository.new(path:)
      now = Time.utc(2026, 10, 7, 12)
      old_run = repository.start_capture!(product: 'SERVERLESS', started_at: now - (31 * 24 * 60 * 60))
      active_run = repository.start_capture!(product: 'SERVERLESS', started_at: now)

      repository.fail_capture!(run_id: old_run, error_message: 'old failure', finished_at: now - (31 * 24 * 60 * 60))
      repository.fail_abandoned_captures!(finished_at: now)
      repository.prune_capture_runs!(before: now - (30 * 24 * 60 * 60))

      latest_run = repository.latest_capture_run(product: 'SERVERLESS')
      assert_equal active_run, latest_run.fetch('id')
      assert_equal 'failed', latest_run.fetch('status')
      assert_equal 'collector exited before completing this capture', latest_run.fetch('error_message')
    ensure
      repository&.close
    end
  end

  def test_records_current_and_historical_serverless_availability
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'availability.sqlite3')
      RunpodGpuAvailability::Migrator.run(path:)
      repository = RunpodGpuAvailability::AvailabilityRepository.new(path:)
      now = Time.utc(2026, 10, 4, 12, 0, 0)
      repository.record_snapshot!(captured_at: now, product: 'SERVERLESS', catalog: catalog('HIGH'))
      repository.record_snapshot!(captured_at: now + 1_800, product: 'SERVERLESS', catalog: catalog('LOW'))

      snapshot, current = repository.current_availabilities(product: 'SERVERLESS')
      assert_equal (now + 1_800).iso8601, snapshot['captured_at']
      assert_equal 'LOW', current.first['availability']

      history = repository.history(product: 'SERVERLESS', since: now - 1)
      assert_equal 2, history.first['observations']
      assert_equal 1, history.first['high_observations']
      assert_equal 1, history.first['low_observations']

      summary = repository.region_availability_summaries(product: 'SERVERLESS', since: now - 1).first
      assert_equal 'US-IL-1', summary['region_id']
      assert_equal 2, summary['snapshots_observed']
      assert_equal 1, summary['high_snapshots']
      assert_equal 1, summary['low_snapshots']
      assert_equal 'HIGH', summary['best_availability']
      assert_equal 'LOW', summary['worst_availability']
    ensure
      repository&.close
    end
  end

  private

  def catalog(availability)
    {
      'gpus' => [{
        'id' => 'NVIDIA GeForce RTX 4090', 'name' => 'RTX 4090', 'pool' => 'ADA_24', 'memory' => 24,
        'price' => { 'serverless' => 1.1 },
        'dataCenters' => [{ 'id' => 'US-IL-1', 'availability' => availability }]
      }]
    }
  end
end
