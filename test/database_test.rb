# frozen_string_literal: true

require_relative "test_helper"

class DatabaseTest < Minitest::Test
  def test_records_current_and_historical_serverless_availability
    Dir.mktmpdir do |directory|
      database = RunpodGpuAvailability::Database.new(path: File.join(directory, "availability.sqlite3"))
      now = Time.utc(2026, 10, 4, 12, 0, 0)
      database.record_snapshot!(captured_at: now, product: "SERVERLESS", catalog: catalog("HIGH"))
      database.record_snapshot!(captured_at: now + 1_800, product: "SERVERLESS", catalog: catalog("LOW"))

      snapshot, current = database.current_availabilities(product: "SERVERLESS")
      assert_equal (now + 1_800).iso8601, snapshot["captured_at"]
      assert_equal "LOW", current.first["availability"]

      history = database.history(product: "SERVERLESS", since: now - 1)
      assert_equal 2, history.first["observations"]
      assert_equal 1, history.first["high_observations"]
      assert_equal 1, history.first["low_observations"]
    ensure
      database&.close
    end
  end

  private

  def catalog(availability)
    {
      "gpus" => [{
        "id" => "NVIDIA GeForce RTX 4090", "name" => "RTX 4090", "pool" => "ADA_24", "memory" => 24,
        "price" => { "serverless" => 1.1 },
        "dataCenters" => [{ "id" => "US-IL-1", "name" => "US Illinois 1", "availability" => availability }]
      }]
    }
  end
end
