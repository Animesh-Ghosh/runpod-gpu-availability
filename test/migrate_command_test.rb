# frozen_string_literal: true

require_relative 'test_helper'
require 'open3'
require 'sqlite3'

class MigrateCommandTest < Minitest::Test
  def test_migrates_the_database_selected_by_the_environment
    Dir.mktmpdir do |directory|
      path = File.join(directory, 'availability.sqlite3')

      _output, status = Open3.capture2e({ 'DATABASE_PATH' => path }, RbConfig.ruby, 'bin/migrate')

      assert_predicate status, :success?
      database = SQLite3::Database.new(path)
      assert_equal 2, database.get_first_value('SELECT version FROM schema_migrations')
    ensure
      database&.close
    end
  end
end
