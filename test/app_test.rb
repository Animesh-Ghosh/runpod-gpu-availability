# frozen_string_literal: true

require_relative "test_helper"
require "rack/mock"

class AppTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @database = RunpodGpuAvailability::Database.new(path: File.join(@directory, "availability.sqlite3"))
    client = Struct.new(:catalog) { def fetch = catalog }.new(catalog)
    @runner = RunpodGpuAvailability::SnapshotRunner.new(client:, database: @database)
    config = RunpodGpuAvailability::Config.new(
      "SNAPSHOT_INTERVAL_SECONDS" => "1800"
    )
    @app = RunpodGpuAvailability::App.rack_app(
      database: @database,
      runner: @runner,
      config:
    )
  end

  def teardown
    @database.close
    FileUtils.remove_entry @directory
  end

  def test_dashboard
    @runner.run

    dashboard = Rack::MockRequest.new(@app).get("/?days=28")
    assert_equal 200, dashboard.status
    assert_includes dashboard.body, "US-IL-1"
    assert_includes dashboard.body, "History: last 28 days"
    assert_includes dashboard.body, "Region status timeline"
    assert_includes dashboard.body, "Current region status"
    assert_includes dashboard.body, "Snapshots every 30 minutes."
    refute_includes dashboard.body, "RTX 4090"
    refute_includes dashboard.body, "US Illinois 1"

    json = Rack::MockRequest.new(@app).get("/dashboard.json?days=28")
    assert_equal 200, json.status
    assert_equal "application/json; charset=utf-8", json["content-type"]
    payload = JSON.parse(json.body)
    assert_equal "SERVERLESS", payload.fetch("product")
    assert_equal 28, payload.fetch("days")
    high = payload.fetch("current").fetch("high")
    assert_equal "US-IL-1", high.fetch("configurations").first.fetch("region_id")
    assert_equal "US-IL-1", high.fetch("regions").first.fetch("region_id")
    refute high.fetch("configurations").first.key?("region_name")
    refute high.fetch("regions").first.key?("region_name")
  end

  def test_exposes_only_canonical_dashboard_routes
    assert_equal 404, Rack::MockRequest.new(@app).get("/.json").status
    assert_equal 404, Rack::MockRequest.new(@app).get("/index.json").status
  end

  private

  def catalog
    {
      "gpus" => [{
        "id" => "NVIDIA GeForce RTX 4090", "name" => "RTX 4090", "pool" => "ADA_24", "memory" => 24,
        "price" => { "serverless" => 1.1 },
        "dataCenters" => [{ "id" => "US-IL-1", "name" => "US Illinois 1", "availability" => "HIGH" }]
      }]
    }
  end
end
