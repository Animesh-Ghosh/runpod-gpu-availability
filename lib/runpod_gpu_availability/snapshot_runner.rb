# frozen_string_literal: true

require "time"

module RunpodGpuAvailability
  class SnapshotRunner
    attr_reader :last_error

    def initialize(client:, database:, product:, clock: Time)
      @client = client
      @database = database
      @product = product
      @clock = clock
      @last_error = nil
    end

    def run
      snapshot_id = @database.record_snapshot!(
        captured_at: @clock.now,
        product: @product,
        catalog: @client.fetch
      )
      @last_error = nil
      snapshot_id
    rescue CatalogClient::Error => error
      @last_error = error.message
      nil
    end
  end
end
