# frozen_string_literal: true

require_relative 'test_helper'

class CatalogClientTest < Minitest::Test
  def test_rejects_a_missing_api_key
    error = assert_raises(RunpodGpuAvailability::CatalogClient::MissingApiKeyError) do
      RunpodGpuAvailability::CatalogClient.new(api_key: '').fetch
    end

    assert_equal 'RUNPOD_API_KEY is required', error.message
  end

  def test_wraps_connection_failures
    error = with_http_start(->(*) { raise Net::OpenTimeout, 'execution expired' }) do
      assert_raises(RunpodGpuAvailability::CatalogClient::RequestError) { client.fetch }
    end

    assert_equal 'RunPod catalog request failed: execution expired', error.message
  end

  def test_wraps_tls_failures
    error = with_http_start(->(*) { raise OpenSSL::SSL::SSLError, 'certificate verify failed' }) do
      assert_raises(RunpodGpuAvailability::CatalogClient::RequestError) { client.fetch }
    end

    assert_equal 'RunPod catalog request failed: certificate verify failed', error.message
  end

  def test_identifies_unsuccessful_http_responses
    response = Struct.new(:code, :body).new('429', 'slow down')

    error = with_http_response(response) do
      assert_raises(RunpodGpuAvailability::CatalogClient::ResponseError) { client.fetch }
    end

    assert_equal 'RunPod catalog request failed (HTTP 429): slow down', error.message
    assert_equal 429, error.status
  end

  def test_identifies_invalid_json_payloads
    response = success_response('{not json}')

    error = with_http_response(response) do
      assert_raises(RunpodGpuAvailability::CatalogClient::InvalidPayloadError) { client.fetch }
    end

    assert_match(/RunPod catalog response was not valid JSON:/, error.message)
  end

  private

  def client = RunpodGpuAvailability::CatalogClient.new(api_key: 'test-key')

  def with_http_response(response, &)
    connection = Object.new
    connection.define_singleton_method(:request) { |_request| response }
    with_http_start(->(*, &block) { block.call(connection) }, &)
  end

  def with_http_start(implementation, &)
    Net::HTTP.stub(:start, implementation, &)
  end

  def success_response(body)
    Class.new(Net::HTTPSuccess) do
      define_method(:initialize) { @body = body }
      attr_reader :body
    end.new
  end
end
