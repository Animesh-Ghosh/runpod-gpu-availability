# frozen_string_literal: true

module RunpodGpuAvailability
  module Web
    module RackResponses
      def self.not_found = [404, { 'content-type' => 'text/plain' }, ["Not found\n"]]

      def self.internal_server_error
        [500, { 'content-type' => 'text/plain' }, ["Internal server error\n"]]
      end
    end
  end
end
