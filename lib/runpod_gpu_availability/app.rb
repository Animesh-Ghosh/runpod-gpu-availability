# frozen_string_literal: true

require "logger"
require "rack"

require_relative "catalog_client"
require_relative "database"
require_relative "dashboard_endpoint"
require_relative "health_endpoint"
require_relative "runtime"
require_relative "scheduler"
require_relative "snapshot_runner"
require_relative "settings"

module RunpodGpuAvailability
  class App
    def self.build(environment: ENV, logger: Logger.new($stdout), database: nil, runner: nil, start_scheduler: nil)
      settings = Settings.new(environment)
      database ||= Database.new(path: settings.database_path)
      runner ||= SnapshotRunner.new(
        client: CatalogClient.new(api_key: settings.api_key, product: settings.product),
        database: database,
        product: settings.product
      )
      scheduler_enabled = start_scheduler.nil? ? settings.scheduler_enabled? : start_scheduler
      scheduler = if scheduler_enabled
        Scheduler.new(
          runner: runner,
          interval_seconds: settings.snapshot_interval_seconds,
          logger: logger
        ).tap(&:start)
      end

      Runtime.new(app: rack_app(database: database, runner: runner, settings: settings), scheduler: scheduler)
    end

    def self.rack_app(database:, runner:, settings:)
      Rack::Builder.new do
        map "/healthz" do
          run HealthEndpoint.new(runner: runner)
        end

        map "/" do
          run DashboardEndpoint.new(
            database: database,
            runner: runner,
            product: settings.product,
            snapshot_cadence: settings.snapshot_cadence
          )
        end
      end.to_app
    end

  end
end
