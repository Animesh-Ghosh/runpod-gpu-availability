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
require_relative "config"

module RunpodGpuAvailability
  class App
    def self.build(environment: ENV)
      config = Config.load(environment)
      database = Database.new(path: config.database_path)
      runner = SnapshotRunner.new(
        client: CatalogClient.new(api_key: config.api_key),
        database:
      )
      scheduler = Scheduler.new(
        runner:,
        interval_seconds: config.snapshot_interval_seconds,
        logger: Logger.new($stdout)
      ).tap(&:start)

      Runtime.new(app: rack_app(database:, runner:, config:), scheduler:)
    end

    def self.rack_app(database:, runner:, config:)
      Rack::Builder.new do
        map "/healthz" do
          run HealthEndpoint.new(runner:)
        end

        map "/" do
          run DashboardEndpoint.new(
            database:,
            runner:,
            product: CatalogClient::PRODUCT,
            snapshot_cadence: config.snapshot_cadence
          )
        end
      end.to_app
    end

  end
end
