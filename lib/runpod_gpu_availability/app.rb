# frozen_string_literal: true

require 'rack'

module RunpodGpuAvailability
  class App
    def initialize
      config = Config.load(ENV)
      repository = AvailabilityRepository.new(path: config.database_path)
      @rack_app = Rack::Builder.new do
        map '/healthz' do
          run HealthEndpoint.new(repository:)
        end

        map '/' do
          run DashboardEndpoint.new(repository:)
        end
      end.to_app
    end

    def call(environment) = @rack_app.call(environment)
  end
end
