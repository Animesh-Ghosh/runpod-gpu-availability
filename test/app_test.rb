# frozen_string_literal: true

require_relative "test_helper"
require "rack/mock"

class AppTest < Minitest::Test
  def setup
    @directory = Dir.mktmpdir
    @database = RunpodGpuAvailability::Database.new(path: File.join(@directory, "availability.sqlite3"))
    client = Struct.new(:catalog) { def fetch = catalog }.new(catalog)
    @runner = RunpodGpuAvailability::SnapshotRunner.new(client: client, database: @database, product: "SERVERLESS")
    @app = RunpodGpuAvailability::App.new(database: @database, runner: @runner, product: "SERVERLESS", snapshot_secret: "secret")
  end

  def teardown
    @database.close
    FileUtils.remove_entry @directory
  end

  def test_dashboard_and_authenticated_manual_snapshot
    unauthorized = Rack::MockRequest.new(@app).post("/internal/snapshots")
    assert_equal 404, unauthorized.status

    response = Rack::MockRequest.new(@app).post("/internal/snapshots", "HTTP_AUTHORIZATION" => "Bearer secret")
    assert_equal 201, response.status

    dashboard = Rack::MockRequest.new(@app).get("/")
    assert_equal 200, dashboard.status
    assert_includes dashboard.body, "RTX 4090"
    assert_includes dashboard.body, "US-IL-1"
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
