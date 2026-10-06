# frozen_string_literal: true

require_relative 'test_helper'

class RuntimeTest < Minitest::Test
  def test_closes_the_scheduler_and_repository
    scheduler = Struct.new(:stopped) do
      def stop = self.stopped = true
    end.new(false)
    repository = Struct.new(:closed) do
      def close = self.closed = true
    end.new(false)
    runtime = RunpodGpuAvailability::Runtime.new(
      app: ->(_environment) { [200, {}, []] },
      scheduler:,
      repository:
    )

    runtime.close

    assert_predicate scheduler, :stopped
    assert_predicate repository, :closed
  end
end
