# frozen_string_literal: true

require 'puma'

require_relative 'app'
require_relative 'config'
require_relative 'migrator'

module RunpodGpuAvailability
  class Server
    def self.run(environment: ENV)
      config = Config.load(environment)
      Migrator.run(path: config.database_path)
      runtime = App.runtime(config:)
      Puma::Launcher.new(puma_configuration(runtime:, environment:)).run
    ensure
      runtime&.close
    end

    def self.puma_configuration(runtime:, environment:)
      Puma::Configuration.new do |user_config|
        user_config.clear_binds!
        user_config.bind("tcp://0.0.0.0:#{environment.fetch('PORT', '8080')}")
        user_config.app(runtime)
      end
    end
    private_class_method :puma_configuration
  end
end
