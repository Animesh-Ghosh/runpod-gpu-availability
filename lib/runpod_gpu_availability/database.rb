# frozen_string_literal: true

require "fileutils"
require "sqlite3"

module RunpodGpuAvailability
  class Database
    def initialize(path:)
      FileUtils.mkdir_p(File.dirname(path))
      @database = SQLite3::Database.new(path)
      @database.results_as_hash = true
      @database.busy_timeout(5_000)
      migrate!
    end

    def record_snapshot!(captured_at:, product:, catalog:)
      @database.transaction do
        @database.execute(
          "INSERT INTO snapshots (captured_at, product) VALUES (?, ?)",
          [captured_at.utc.iso8601, product]
        )
        snapshot_id = @database.last_insert_row_id

        Array(catalog.fetch("gpus")).each do |gpu|
          Array(gpu["dataCenters"]).each do |data_center|
            parameters = [
              snapshot_id,
              data_center.fetch("id"),
              data_center["name"],
              gpu.fetch("id"),
              gpu.fetch("name"),
              gpu["pool"],
              gpu["memory"],
              data_center["availability"] || gpu["availability"] || "UNKNOWN",
              gpu.dig("price", "serverless")
            ]
            @database.execute(<<~SQL, parameters)
              INSERT INTO gpu_availabilities (
                snapshot_id, region_id, region_name, gpu_id, gpu_name, pool,
                vram_gb, availability, serverless_price_usd_per_hour
              ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            SQL
          end
        end

        snapshot_id
      end
    end

    def latest_snapshot(product:)
      @database.get_first_row(
        "SELECT * FROM snapshots WHERE product = ? ORDER BY captured_at DESC LIMIT 1",
        [product]
      )
    end

    def current_availabilities(product:)
      snapshot = latest_snapshot(product: product)
      return [nil, []] unless snapshot

      records = @database.execute(<<~SQL, [snapshot["id"]])
        SELECT *
        FROM gpu_availabilities
        WHERE snapshot_id = ?
        ORDER BY
          CASE availability WHEN 'HIGH' THEN 0 WHEN 'MEDIUM' THEN 1 WHEN 'LOW' THEN 2 ELSE 3 END,
          region_id, serverless_price_usd_per_hour, gpu_name
      SQL
      [snapshot, records]
    end

    def history(product:, since:)
      @database.execute(<<~SQL, [product, since.utc.iso8601])
        SELECT
          a.region_id,
          MAX(a.region_name) AS region_name,
          a.gpu_name,
          a.pool,
          a.vram_gb,
          MIN(a.serverless_price_usd_per_hour) AS lowest_price_usd_per_hour,
          COUNT(*) AS observations,
          SUM(a.availability = 'HIGH') AS high_observations,
          SUM(a.availability = 'MEDIUM') AS medium_observations,
          SUM(a.availability = 'LOW') AS low_observations,
          MAX(s.captured_at) AS last_seen_at
        FROM gpu_availabilities a
        JOIN snapshots s ON s.id = a.snapshot_id
        WHERE s.product = ? AND s.captured_at >= ?
        GROUP BY a.region_id, a.gpu_id
        ORDER BY high_observations DESC, medium_observations DESC,
          low_observations DESC, lowest_price_usd_per_hour, a.region_id, a.gpu_name
      SQL
    end

    def snapshot_count(product:)
      @database.get_first_value("SELECT COUNT(*) FROM snapshots WHERE product = ?", [product])
    end

    def close
      @database.close
    end

    private

    def migrate!
      @database.execute_batch <<~SQL
        PRAGMA journal_mode = WAL;
        PRAGMA foreign_keys = ON;

        CREATE TABLE IF NOT EXISTS snapshots (
          id INTEGER PRIMARY KEY,
          captured_at TEXT NOT NULL,
          product TEXT NOT NULL
        );

        CREATE TABLE IF NOT EXISTS gpu_availabilities (
          id INTEGER PRIMARY KEY,
          snapshot_id INTEGER NOT NULL REFERENCES snapshots(id) ON DELETE CASCADE,
          region_id TEXT NOT NULL,
          region_name TEXT,
          gpu_id TEXT NOT NULL,
          gpu_name TEXT NOT NULL,
          pool TEXT,
          vram_gb INTEGER,
          availability TEXT NOT NULL,
          serverless_price_usd_per_hour REAL
        );

        CREATE INDEX IF NOT EXISTS snapshots_product_captured_at
          ON snapshots(product, captured_at DESC);
        CREATE INDEX IF NOT EXISTS gpu_availabilities_snapshot_id
          ON gpu_availabilities(snapshot_id);
      SQL
    end
  end
end
