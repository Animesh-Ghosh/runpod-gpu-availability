# frozen_string_literal: true

require 'json'
require 'rack'

require_relative 'rack_responses'

module RunpodGpuAvailability
  module Web
    class HealthEndpoint
      def initialize(repository:)
        @repository = repository
      end

      def call(environment)
        if handles?(environment)
          [200, { 'content-type' => 'application/json' }, [JSON.generate(health_payload)]]
        else
          RackResponses.not_found
        end
      end

      private

      def handles?(environment) = Rack::Request.new(environment).get?

      def health_payload
        latest_capture_run = @repository.latest_capture_run(product: CatalogClient::PRODUCT)
        { ok: true, latest_capture_run: }
      end
    end
  end
end
