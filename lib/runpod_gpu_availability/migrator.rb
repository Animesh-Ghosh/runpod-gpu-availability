# frozen_string_literal: true

require 'fileutils'
require 'sequel'
require 'sequel/extensions/migration'

module RunpodGpuAvailability
  class Migrator
    def self.run(path:)
      FileUtils.mkdir_p(File.dirname(path))
      database = Sequel.sqlite(path, timeout: 5_000)
      database.run('PRAGMA journal_mode = WAL')
      database.run('PRAGMA foreign_keys = ON')
      Sequel::Migrator.run(
        database,
        File.expand_path('../../db/migrations', __dir__),
        table: :schema_migrations
      )
    ensure
      database&.disconnect
    end
  end
end
