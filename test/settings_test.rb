# frozen_string_literal: true

require_relative "test_helper"

class SettingsTest < Minitest::Test
  def test_reads_environment_once_and_formats_snapshot_cadence
    settings = RunpodGpuAvailability::Settings.new(
      "RUNPOD_PRODUCT" => "SERVERLESS",
      "SNAPSHOT_INTERVAL_SECONDS" => "1800",
      "SCHEDULER_ENABLED" => "true"
    )

    assert_equal "SERVERLESS", settings.product
    assert_equal 1_800, settings.snapshot_interval_seconds
    assert_predicate settings, :scheduler_enabled?
    assert_equal "30 minutes", settings.snapshot_cadence
  end

  def test_rejects_a_non_positive_snapshot_interval
    assert_raises(ArgumentError) do
      RunpodGpuAvailability::Settings.new("SNAPSHOT_INTERVAL_SECONDS" => "0")
    end
  end
end
