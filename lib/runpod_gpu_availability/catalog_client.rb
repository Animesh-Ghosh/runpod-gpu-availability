# frozen_string_literal: true

require "json"
require "net/http"
require "uri"

module RunpodGpuAvailability
  class CatalogClient
    API_URL = "https://api.runpod.io/v2/catalog/gpus".freeze
    PRODUCT = "SERVERLESS"

    class Error < StandardError; end

    def initialize(api_key:)
      @api_key = api_key
    end

    def fetch
      raise Error, "RUNPOD_API_KEY is required" if @api_key.nil? || @api_key.empty?

      uri = URI(API_URL)
      uri.query = URI.encode_www_form(include: "AVAILABILITY", product: PRODUCT)
      request = Net::HTTP::Get.new(uri)
      request["Authorization"] = "Bearer #{@api_key}"
      request["Accept"] = "application/json"

      response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 5, read_timeout: 20) do |connection|
        connection.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        raise Error, "RunPod catalog request failed (HTTP #{response.code}): #{response.body}"
      end

      JSON.parse(response.body)
    rescue JSON::ParserError => error
      raise Error, "RunPod catalog response was not valid JSON: #{error.message}"
    end
  end
end
