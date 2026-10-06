# frozen_string_literal: true

require 'logger'
require 'rack'

require_relative 'availability_repository'
require_relative 'catalog_client'
require_relative 'dashboard_endpoint'
require_relative 'health_endpoint'
require_relative 'runtime'
require_relative 'scheduler'
require_relative 'snapshot_runner'
require_relative 'config'

module RunpodGpuAvailability
  class App
    def self.build(environment: ENV)
      config = Config.load(environment)
      repository = AvailabilityRepository.new(path: config.database_path)
      runner = SnapshotRunner.new(
        client: CatalogClient.new(api_key: config.api_key),
        database: repository
      )

      rack_app(repository:, runner:, config:)
    end

    def self.runtime(config:)
      repository = AvailabilityRepository.new(path: config.database_path)
      runner = SnapshotRunner.new(
        client: CatalogClient.new(api_key: config.api_key),
        database: repository
      )
      scheduler = Scheduler.new(
        runner:,
        interval_seconds: config.snapshot_interval_seconds,
        logger: Logger.new($stdout)
      ).tap(&:start)

      Runtime.new(app: rack_app(repository:, runner:, config:), scheduler:, repository:)
    end

    def self.rack_app(repository:, runner:, config:)
      Rack::Builder.new do
        map '/healthz' do
          run HealthEndpoint.new(runner:)
        end

        map '/' do
          run DashboardEndpoint.new(
            database: repository,
            runner:,
            product: CatalogClient::PRODUCT,
            snapshot_cadence: config.snapshot_cadence
          )
        end
      end.to_app
    end
  end
end
