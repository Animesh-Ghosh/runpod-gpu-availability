# frozen_string_literal: true

module RunpodGpuAvailability
  Config = Data.define(:api_key, :database_path) do
    def self.load(environment)
      new(
        api_key: environment.fetch('RUNPOD_API_KEY', ''),
        database_path: environment.fetch('DATABASE_PATH', 'data/availability.sqlite3')
      )
    end
  end
end
