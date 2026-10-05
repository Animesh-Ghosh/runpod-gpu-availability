# frozen_string_literal: true

module RunpodGpuAvailability
  class SnapshotRunner
    attr_reader :last_error

    def initialize(client:, database:)
      @client = client
      @database = database
      @last_error = nil
    end

    def run
      snapshot_id = @database.record_snapshot!(
        captured_at: Time.now,
        product: CatalogClient::PRODUCT,
        catalog: @client.fetch
      )
      @last_error = nil
      snapshot_id
    rescue CatalogClient::Error => e
      @last_error = e.message
      nil
    end
  end
end
