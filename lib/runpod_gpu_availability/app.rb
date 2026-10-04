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
    def self.build(environment: ENV, logger: Logger.new($stdout), database: nil, runner: nil, start_scheduler: false)
      product = environment.fetch("RUNPOD_PRODUCT", "SERVERLESS")
      database ||= Database.new(path: environment.fetch("DATABASE_PATH", "data/availability.sqlite3"))
      runner ||= SnapshotRunner.new(
        client: CatalogClient.new(api_key: environment.fetch("RUNPOD_API_KEY", ""), product: product),
        database: database,
        product: product
      )
      if start_scheduler
        Scheduler.new(
          runner: runner,
          interval_seconds: Integer(environment.fetch("SNAPSHOT_INTERVAL_SECONDS", "3600")),
          logger: logger
        ).start
      end
      Rack::Builder.new do
        map "/healthz" do
          run HealthEndpoint.new(runner: runner)
        end

        map "/" do
          run DashboardEndpoint.new(database: database, runner: runner, product: product)
        end
      end.to_app
    end

    class HealthEndpoint
      def initialize(runner:)
        @runner = runner
      end

      def call(environment)
        return not_found unless Rack::Request.new(environment).get?

        [200, json_headers, [JSON.generate(ok: true, last_error: @runner.last_error)]]
      end

      private

      def json_headers = { "content-type" => "application/json" }

      def not_found = [404, { "content-type" => "text/plain" }, ["Not found\n"]]
    end

    class DashboardEndpoint
      def initialize(database:, runner:, product:)
        @database = database
        @runner = runner
        @product = product
      end

      def call(environment)
        request = Rack::Request.new(environment)
        return not_found unless request.get? && dashboard_path?(request.path)

        days = Integer(request.params.fetch("days", "7"), exception: false).to_i.clamp(1, 90)
        snapshot, current = @database.current_availabilities(product: @product)
        data = dashboard_data(snapshot: snapshot, current: current, days: days)
        return json(data) if json_request?(request)

        body = Dashboard.new(**data).render
        [200, { "content-type" => "text/html; charset=utf-8" }, [body]]
      end

      private

      def dashboard_path?(path)
        ["/", "/.json", "/dashboard.html", "/dashboard.json", "/index.json"].include?(path)
      end

      def dashboard_data(snapshot:, current:, days:)
        since = Time.now - (days * 24 * 60 * 60)
        {
          product: @product,
          snapshot: clean_row(snapshot),
          current: current.map { |row| clean_row(row) },
          current_regions: @database.current_region_statuses(product: @product).map { |row| clean_row(row) },
          history: @database.history(product: @product, since: since).map { |row| clean_row(row) },
          region_statuses: @database.region_statuses(product: @product, since: since).map { |row| clean_row(row) },
          snapshot_count: @database.snapshot_count(product: @product),
          last_error: @runner.last_error,
          days: days
        }
      end

      def clean_row(row)
        row&.each_with_object({}) { |(key, value), result| result[key] = value if key.is_a?(String) }
      end

      def json_request?(request)
        request.path.end_with?(".json") || request.params["format"] == "json" ||
          request.get_header("HTTP_ACCEPT").to_s.include?("application/json")
      end

      def json(data)
        [200, { "content-type" => "application/json; charset=utf-8" }, [JSON.generate(data)]]
      end

      def not_found = [404, { "content-type" => "text/plain" }, ["Not found\n"]]
    end
  end
end
