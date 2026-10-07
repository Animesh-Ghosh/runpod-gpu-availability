# frozen_string_literal: true

require 'logger'

require_relative 'rack_responses'

module RunpodGpuAvailability
  module Web
    class ErrorHandler
      def initialize(app:)
        @app = app
        @logger = Logger.new($stderr)
      end

      def call(environment)
        @app.call(environment)
      rescue StandardError => e
        @logger.error(event: 'request_failed', error_class: e.class.name, message: e.message)
        RackResponses.internal_server_error
      end
    end
  end
end
