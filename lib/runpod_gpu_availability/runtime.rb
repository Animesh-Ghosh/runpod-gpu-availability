# frozen_string_literal: true

module RunpodGpuAvailability
  class Runtime
    def initialize(app:, scheduler:, repository:)
      @app = app
      @scheduler = scheduler
      @repository = repository
    end

    def call(environment) = @app.call(environment)

    def close
      @scheduler.stop
      @repository.close
    end
  end
end
