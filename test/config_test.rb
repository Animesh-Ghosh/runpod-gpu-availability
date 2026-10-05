# frozen_string_literal: true

require_relative "test_helper"

class ConfigTest < Minitest::Test
  def test_reads_environment_once_and_formats_snapshot_cadence
    config = RunpodGpuAvailability::Config.new(
      "SNAPSHOT_INTERVAL_SECONDS" => "1800"
    )

    assert_equal 1_800, config.snapshot_interval_seconds
    assert_equal "30 minutes", config.snapshot_cadence
  end

  def test_rejects_a_non_positive_snapshot_interval
    assert_raises(ArgumentError) do
      RunpodGpuAvailability::Config.new("SNAPSHOT_INTERVAL_SECONDS" => "0")
    end
  end
end
