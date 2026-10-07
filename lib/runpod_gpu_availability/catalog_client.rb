# frozen_string_literal: true

require 'json'
require 'net/http'
require 'openssl'
require 'uri'

module RunpodGpuAvailability
  class CatalogClient
    API_URL = 'https://api.runpod.io/v2/catalog/gpus'
    PRODUCT = 'SERVERLESS'

    class Error < StandardError; end

    class MissingApiKeyError < Error; end

    class RequestError < Error
      def initialize(error)
        super("RunPod catalog request failed: #{error.message}")
      end
    end

    class ResponseError < Error
      attr_reader :status

      def initialize(status:, body:)
        @status = status
        super("RunPod catalog request failed (HTTP #{status}): #{body}")
      end
    end

    class InvalidPayloadError < Error
      def initialize(error)
        super("RunPod catalog response was not valid JSON: #{error.message}")
      end
    end

    def initialize(api_key:)
      @api_key = api_key
    end

    def fetch
      validate_api_key!
      parse(response_body)
    end

    private

    def validate_api_key!
      raise MissingApiKeyError, 'RUNPOD_API_KEY is required' if @api_key.nil? || @api_key.empty?
    end

    def response_body
      uri = URI(API_URL)
      uri.query = URI.encode_www_form(include: 'AVAILABILITY', product: PRODUCT)
      request = Net::HTTP::Get.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Accept'] = 'application/json'

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |connection|
        connection.request(request)
      end

      validate_response!(response)
      response.body
    rescue Net::OpenTimeout, Net::ReadTimeout, OpenSSL::SSL::SSLError, SocketError, SystemCallError, EOFError => e
      raise RequestError, e
    end

    def validate_response!(response)
      return if response.is_a?(Net::HTTPSuccess)

      raise ResponseError.new(status: Integer(response.code, 10), body: response.body)
    end

    def parse(body)
      JSON.parse(body)
    rescue JSON::ParserError => e
      raise InvalidPayloadError, e
    end
  end
end
