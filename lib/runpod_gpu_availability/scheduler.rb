# frozen_string_literal: true

require 'rufus-scheduler'

module RunpodGpuAvailability
  class Scheduler
    def initialize(runner:, interval_seconds:, logger:, scheduler: nil)
      @runner = runner
      @interval_seconds = interval_seconds
      @logger = logger
      @scheduler = scheduler || Rufus::Scheduler.new
    end

    def start
      @scheduler.every(@interval_seconds, first_in: 5, overlap: false) { capture }
    end

    def stop = @scheduler.shutdown(wait: false)

    private

    def capture
      snapshot_id = @runner.run
      @logger.info(event: 'snapshot_finished', snapshot_id: snapshot_id, error: @runner.last_error)
    rescue StandardError => e
      @logger.error(event: 'snapshot_crashed', error: e.message)
    end
  end
end
