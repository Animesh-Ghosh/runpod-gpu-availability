# frozen_string_literal: true

module RunpodGpuAvailability
  class Config
    DEFAULT_SNAPSHOT_INTERVAL_SECONDS = 3_600

    attr_reader :api_key, :database_path, :product, :snapshot_interval_seconds

    def initialize(environment)
      @api_key = environment.fetch("RUNPOD_API_KEY", "")
      @database_path = environment.fetch("DATABASE_PATH", "data/availability.sqlite3")
      @product = environment.fetch("RUNPOD_PRODUCT", "SERVERLESS")
      @snapshot_interval_seconds = Integer(
        environment.fetch("SNAPSHOT_INTERVAL_SECONDS", DEFAULT_SNAPSHOT_INTERVAL_SECONDS.to_s)
      )
      raise ArgumentError, "SNAPSHOT_INTERVAL_SECONDS must be positive" unless @snapshot_interval_seconds.positive?
    end

    def snapshot_cadence
      return "#{snapshot_interval_seconds / 3_600} hours" if (snapshot_interval_seconds % 3_600).zero? && snapshot_interval_seconds > 3_600
      return "1 hour" if snapshot_interval_seconds == 3_600
      return "#{snapshot_interval_seconds / 60} minutes" if (snapshot_interval_seconds % 60).zero?

      "#{snapshot_interval_seconds} seconds"
    end
  end
end
