# frozen_string_literal: true

require 'logger'

module RunpodGpuAvailability
  class SnapshotJob
    def self.call(config:)
      repository = AvailabilityRepository.new(path: config.database_path)
      repository.fail_abandoned_captures!(finished_at: Time.now)

      client = CatalogClient.new(api_key: config.api_key)
      capture = CaptureSnapshot.new(client:, repository:)
      snapshot_id = capture.call
      capture_run = repository.latest_capture_run(product: CatalogClient::PRODUCT)
      Logger.new($stdout).info(
        event: 'snapshot_finished',
        snapshot_id:,
        status: capture_run&.fetch('status'),
        error: capture_run&.fetch('error_message')
      )
      snapshot_id
    ensure
      repository&.close
    end
  end
end
