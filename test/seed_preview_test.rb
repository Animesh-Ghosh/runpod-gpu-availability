# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'sqlite3'

class SeedPreviewTest < Minitest::Test
  def test_creates_a_versioned_preview_database
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'preview.sqlite3')

      _output, status = Open3.capture2e(RbConfig.ruby, 'bin/seed_preview', path)

      assert_predicate status, :success?
      database = SQLite3::Database.new(path)
      assert_equal 2, database.get_first_value('SELECT version FROM schema_migrations')
      assert_equal 168, database.get_first_value('SELECT COUNT(*) FROM snapshots')
    ensure
      database&.close
    end
  end
end
