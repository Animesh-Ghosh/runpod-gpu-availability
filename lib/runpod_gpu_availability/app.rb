# frozen_string_literal: true

require "json"
require "logger"
require "rack"
require "time"

require_relative "catalog_client"
require_relative "database"
require_relative "dashboard"
require_relative "scheduler"
require_relative "snapshot_runner"

module RunpodGpuAvailability
  class App
    def self.build(environment: ENV, logger: Logger.new($stdout), start_scheduler: true)
      product = environment.fetch("RUNPOD_PRODUCT", "SERVERLESS")
      database = Database.new(path: environment.fetch("DATABASE_PATH", "data/availability.sqlite3"))
      runner = SnapshotRunner.new(
        client: CatalogClient.new(api_key: environment.fetch("RUNPOD_API_KEY", ""), product: product),
        database: database,
        product: product
      )
      if start_scheduler && environment.fetch("SCHEDULER_ENABLED", "true") == "true"
        Scheduler.new(
          runner: runner,
          interval_seconds: Integer(environment.fetch("SNAPSHOT_INTERVAL_SECONDS", "1800")),
          logger: logger
        ).start
      end
      new(database: database, runner: runner, product: product, snapshot_secret: environment["SNAPSHOT_SECRET"])
    end

    def initialize(database:, runner:, product:, snapshot_secret:)
      @database = database
      @runner = runner
      @product = product
      @snapshot_secret = snapshot_secret
    end

    def call(environment)
      request = Rack::Request.new(environment)
      return health if request.get? && request.path == "/healthz"
      return snapshot(request) if request.post? && request.path == "/internal/snapshots"
      return dashboard if request.get? && ["/", "/dashboard.html"].include?(request.path)

      [404, { "content-type" => "text/plain" }, ["Not found\n"]]
    end

    private

    def health
      [200, { "content-type" => "application/json" }, [JSON.generate(ok: true, last_error: @runner.last_error)]]
    end

    def snapshot(request)
      return [404, { "content-type" => "text/plain" }, ["Not found\n"]] unless authorized?(request)

      snapshot_id = @runner.run
      status = snapshot_id ? 201 : 502
      [status, { "content-type" => "application/json" }, [JSON.generate(snapshot_id: snapshot_id, error: @runner.last_error)]]
    end

    def dashboard
      snapshot, current = @database.current_availabilities(product: @product)
      body = Dashboard.new(
        product: @product,
        snapshot: snapshot,
        current: current,
        history: @database.history(product: @product, since: Time.now - (7 * 24 * 60 * 60)),
        snapshot_count: @database.snapshot_count(product: @product),
        last_error: @runner.last_error
      ).render
      [200, { "content-type" => "text/html; charset=utf-8" }, [body]]
    end

    def authorized?(request)
      @snapshot_secret && Rack::Utils.secure_compare(request.get_header("HTTP_AUTHORIZATION").to_s, "Bearer #{@snapshot_secret}")
    end
  end
end
