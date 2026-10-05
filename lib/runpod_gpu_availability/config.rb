# frozen_string_literal: true

module RunpodGpuAvailability
  DEFAULT_SNAPSHOT_INTERVAL_SECONDS = 3_600

  Config = Data.define(:api_key, :database_path, :snapshot_interval_seconds) do
    def self.load(environment)
      snapshot_interval_seconds = Integer(
        environment.fetch('SNAPSHOT_INTERVAL_SECONDS', DEFAULT_SNAPSHOT_INTERVAL_SECONDS.to_s)
      )
      raise ArgumentError, 'SNAPSHOT_INTERVAL_SECONDS must be positive' unless snapshot_interval_seconds.positive?

      new(
        api_key: environment.fetch('RUNPOD_API_KEY', ''),
        database_path: environment.fetch('DATABASE_PATH', 'data/availability.sqlite3'),
        snapshot_interval_seconds:
      )
    end

    def snapshot_cadence
      if (snapshot_interval_seconds % 3_600).zero? && snapshot_interval_seconds > 3_600
        return "#{snapshot_interval_seconds / 3_600} hours"
      end
      return '1 hour' if snapshot_interval_seconds == 3_600
      return "#{snapshot_interval_seconds / 60} minutes" if (snapshot_interval_seconds % 60).zero?

      "#{snapshot_interval_seconds} seconds"
    end
  end
end
