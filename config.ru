# frozen_string_literal: true

require_relative "lib/runpod_gpu_availability/app"

run RunpodGpuAvailability::App.build(
  start_scheduler: ENV.fetch("SCHEDULER_ENABLED", "true") == "true"
)
