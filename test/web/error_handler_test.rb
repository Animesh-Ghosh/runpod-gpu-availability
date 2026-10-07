# frozen_string_literal: true

require_relative '../test_helper'

class ErrorHandlerTest < Minitest::Test
  def test_hides_unexpected_errors_from_clients
    app = RunpodGpuAvailability::Web::ErrorHandler.new(app: ->(_) { raise 'database password: secret' })

    status, headers, body = app.call({})

    assert_equal 500, status
    assert_equal 'text/plain', headers.fetch('content-type')
    assert_equal ["Internal server error\n"], body
  end
end
