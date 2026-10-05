# frozen_string_literal: true

module RunpodGpuAvailability
  class Runtime
    def initialize(app:, scheduler:)
      @app = app
      @scheduler = scheduler
    end

    def call(environment) = @app.call(environment)

  end
end
