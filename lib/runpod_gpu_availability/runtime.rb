# frozen_string_literal: true

module RunpodGpuAvailability
  class Runtime
    attr_reader :scheduler

    def initialize(app:, scheduler:)
      @app = app
      @scheduler = scheduler
    end

    def call(environment)
      @app.call(environment)
    end

    def close
      @scheduler&.shutdown(:wait)
    end
  end
end
