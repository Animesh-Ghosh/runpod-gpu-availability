# frozen_string_literal: true

require 'json'
require 'rack'

module RunpodGpuAvailability
  class HealthEndpoint
    def initialize(runner:)
      @runner = runner
    end

    def call(environment)
      return not_found unless Rack::Request.new(environment).get?

      [200, { 'content-type' => 'application/json' }, [JSON.generate(ok: true, last_error: @runner.last_error)]]
    end

    private

    def not_found = [404, { 'content-type' => 'text/plain' }, ["Not found\n"]]
  end
end
