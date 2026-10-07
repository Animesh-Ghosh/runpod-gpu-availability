# frozen_string_literal: true

require 'json'
require 'rack'

require_relative 'dashboard'
require_relative 'dashboard_data'
require_relative 'rack_responses'

module RunpodGpuAvailability
  module Web
    class DashboardEndpoint
      DASHBOARD_PATHS = ['/', '/dashboard.json'].freeze

      def initialize(repository:)
        @dashboard_data = DashboardData.new(repository:)
      end

      def call(environment)
        request = Rack::Request.new(environment)
        if handles?(request)
          content_type, body = response_for(request)
          [200, { 'content-type' => content_type }, [body]]
        else
          RackResponses.not_found
        end
      end

      private

      def handles?(request) = request.get? && DASHBOARD_PATHS.include?(request.path)

      def response_for(request)
        days = requested_days(request)
        return json_response(days:) if json_request?(request)

        html_response(days:)
      end

      def json_response(days:) = ['application/json; charset=utf-8', JSON.generate(@dashboard_data.json(days:))]

      def html_response(days:) = ['text/html; charset=utf-8', Dashboard.new(**@dashboard_data.html(days:)).render]

      def requested_days(request)
        Integer(request.params.fetch('days', '7'), exception: false).to_i.clamp(1, 90)
      end

      def json_request?(request)
        request.path.end_with?('.json') || request.params['format'] == 'json' ||
          request.get_header('HTTP_ACCEPT').to_s.include?('application/json')
      end
    end
  end
end
