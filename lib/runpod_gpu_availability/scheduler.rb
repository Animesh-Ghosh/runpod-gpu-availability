# frozen_string_literal: true

module RunpodGpuAvailability
  class Scheduler
    def initialize(runner:, interval_seconds:, logger:)
      @runner = runner
      @interval_seconds = interval_seconds
      @logger = logger
    end

    def start
      @thread = Thread.new do
        loop do
          snapshot_id = @runner.run
          @logger.info(event: "snapshot_finished", snapshot_id: snapshot_id, error: @runner.last_error)
          sleep @interval_seconds
        end
      end
    end
  end
end
