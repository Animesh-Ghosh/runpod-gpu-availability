# frozen_string_literal: true

module RunpodGpuAvailability
  class CaptureSnapshot
    RETENTION_SECONDS = 30 * 24 * 60 * 60

    def initialize(client:, repository:)
      @client = client
      @repository = repository
    end

    def call
      run_id = nil
      started_at = Time.now
      run_id = @repository.start_capture!(product: CatalogClient::PRODUCT, started_at:)
      catalog = @client.fetch
      snapshot_id = @repository.complete_capture!(
        run_id:,
        captured_at: started_at,
        product: CatalogClient::PRODUCT,
        catalog:,
        finished_at: Time.now
      )
      snapshot_id
    rescue CatalogClient::Error => e
      @repository.fail_capture!(run_id:, error_message: e.message, finished_at: Time.now)
      nil
    rescue StandardError => e
      @repository.fail_capture!(run_id:, error_message: e.message, finished_at: Time.now) if run_id
      raise
    ensure
      prune if run_id
    end

    private

    def prune = @repository.prune_capture_runs!(before: Time.now - RETENTION_SECONDS)
  end
end
