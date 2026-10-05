# frozen_string_literal: true

require_relative 'test_helper'

class DatabaseTest < Minitest::Test
  def test_records_current_and_historical_serverless_availability
    Dir.mktmpdir do |directory|
      database = RunpodGpuAvailability::Database.new(path: File.join(directory, 'availability.sqlite3'))
      now = Time.utc(2026, 10, 4, 12, 0, 0)
      database.record_snapshot!(captured_at: now, product: 'SERVERLESS', catalog: catalog('HIGH'))
      database.record_snapshot!(captured_at: now + 1_800, product: 'SERVERLESS', catalog: catalog('LOW'))

      snapshot, current = database.current_availabilities(product: 'SERVERLESS')
      assert_equal (now + 1_800).iso8601, snapshot['captured_at']
      assert_equal 'LOW', current.first['availability']

      history = database.history(product: 'SERVERLESS', since: now - 1)
      assert_equal 2, history.first['observations']
      assert_equal 1, history.first['high_observations']
      assert_equal 1, history.first['low_observations']
      refute history.first.key?('region_name')
    ensure
      database&.close
    end
  end

  def test_removes_the_legacy_region_name_column
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'availability.sqlite3')
      legacy_database = SQLite3::Database.new(path)
      legacy_database.execute_batch <<~SQL
        CREATE TABLE snapshots (id INTEGER PRIMARY KEY, captured_at TEXT NOT NULL, product TEXT NOT NULL);
        CREATE TABLE gpu_availabilities (
          id INTEGER PRIMARY KEY,
          snapshot_id INTEGER NOT NULL,
          region_id TEXT NOT NULL,
          region_name TEXT,
          gpu_id TEXT NOT NULL,
          gpu_name TEXT NOT NULL,
          pool TEXT,
          vram_gb INTEGER,
          availability TEXT NOT NULL,
          serverless_price_usd_per_hour REAL
        );
      SQL
      legacy_database.close

      database = RunpodGpuAvailability::Database.new(path:)
      database.close
      database = nil
      inspection_database = SQLite3::Database.new(path)
      columns = inspection_database.table_info('gpu_availabilities').map { |column| column.fetch('name') }

      refute_includes columns, 'region_name'
    ensure
      database&.close
      inspection_database&.close
    end
  end

  private

  def catalog(availability)
    {
      'gpus' => [{
        'id' => 'NVIDIA GeForce RTX 4090', 'name' => 'RTX 4090', 'pool' => 'ADA_24', 'memory' => 24,
        'price' => { 'serverless' => 1.1 },
        'dataCenters' => [{ 'id' => 'US-IL-1', 'name' => 'US Illinois 1', 'availability' => availability }]
      }]
    }
  end
end
