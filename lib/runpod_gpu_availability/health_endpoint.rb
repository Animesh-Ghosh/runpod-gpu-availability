# frozen_string_literal: true

require 'json'
require 'rack'

module RunpodGpuAvailability
  class HealthEndpoint
    def initialize(repository:)
      @repository = repository
    end

    def call(environment)
      return not_found unless Rack::Request.new(environment).get?

      latest_capture_run = @repository.latest_capture_run(product: CatalogClient::PRODUCT)
      [200, { 'content-type' => 'application/json' }, [JSON.generate(ok: true, latest_capture_run:)]]
    end

    private

    def not_found = [404, { 'content-type' => 'text/plain' }, ["Not found\n"]]
  end
end
