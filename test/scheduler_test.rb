# frozen_string_literal: true

require_relative "test_helper"

class SchedulerTest < Minitest::Test
  FakeScheduler = Struct.new(:calls) do
    def every(interval, **options, &block)
      calls << [interval, options, block]
      :scheduled_job
    end
  end

  def test_schedules_non_overlapping_captures
    runner = Struct.new(:last_error) do
      def run = 42
    end.new
    scheduler = FakeScheduler.new([])
    service = RunpodGpuAvailability::Scheduler.new(
      runner: runner,
      interval_seconds: 3_600,
      logger: Logger.new(File::NULL),
      scheduler: scheduler
    )

    assert_equal :scheduled_job, service.start
    assert_equal 1, scheduler.calls.length
    interval, options, callback = scheduler.calls.first
    assert_equal 3_600, interval
    assert_equal({ first_in: 5, overlap: false }, options)
    assert_kind_of Proc, callback
  end
end
