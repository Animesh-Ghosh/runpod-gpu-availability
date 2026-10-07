# frozen_string_literal: true

require_relative 'test_helper'
require 'sqlite3'

class MigratorTest < Minitest::Test
  def test_baselines_the_existing_schema_without_losing_recorded_snapshots
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'availability.sqlite3')
      database = SQLite3::Database.new(path)
      database.execute_batch <<~SQL
        CREATE TABLE snapshots (id INTEGER PRIMARY KEY, captured_at TEXT NOT NULL, product TEXT NOT NULL);
        CREATE TABLE gpu_availabilities (
          id INTEGER PRIMARY KEY,
          snapshot_id INTEGER NOT NULL REFERENCES snapshots(id) ON DELETE CASCADE,
          region_id TEXT NOT NULL,
          gpu_id TEXT NOT NULL,
          gpu_name TEXT NOT NULL,
          pool TEXT,
          vram_gb INTEGER,
          availability TEXT NOT NULL,
          serverless_price_usd_per_hour REAL
        );
      SQL
      database.execute <<~SQL
        INSERT INTO snapshots (id, captured_at, product)
        VALUES (1, '2026-10-06T00:00:00Z', 'SERVERLESS')
      SQL
      database.close

      RunpodGpuAvailability::Migrator.run(path:)

      database = SQLite3::Database.new(path)
      assert_equal 1, database.get_first_value('SELECT COUNT(*) FROM snapshots')
      assert_equal 3, database.get_first_value('SELECT version FROM schema_migrations')
      columns = database.table_info('capture_runs').map { |column| column.fetch('name') }
      assert_equal %w[id product started_at finished_at status error_message snapshot_id], columns
    ensure
      database&.close
    end
  end
end
