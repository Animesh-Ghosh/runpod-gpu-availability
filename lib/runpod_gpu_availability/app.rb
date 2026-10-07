# frozen_string_literal: true

require 'rack'

module RunpodGpuAvailability
  class App
    def initialize
      config = Config.load(ENV)
      repository = AvailabilityRepository.new(path: config.database_path)
      routes = Rack::Builder.new do
        map '/healthz' do
          run Web::HealthEndpoint.new(repository:)
        end

        map '/' do
          run Web::DashboardEndpoint.new(repository:)
        end
      end.to_app
      @rack_app = Web::ErrorHandler.new(app: routes)
    end

    def call(environment) = @rack_app.call(environment)
  end
end
