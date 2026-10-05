# frozen_string_literal: true

require "cgi/escape"
require "erb"
require "time"

module RunpodGpuAvailability
  class AvailabilityChart
    COLORS = {
      "HIGH" => "#22c55e",
      "MEDIUM" => "#f59e0b",
      "LOW" => "#ef4444",
      "UNKNOWN" => "#94a3b8"
    }.freeze
    TEMPLATE_PATH = File.expand_path("../../views/availability_chart.svg.erb", __dir__)

    def initialize(statuses:)
      @statuses = statuses
    end

    def render
      return "<p>Region timeline appears after the first successful snapshot.</p>" if statuses.empty?

      ERB.new(File.read(TEMPLATE_PATH), trim_mode: "-").result(binding)
    end

    private

    attr_reader :statuses

    def timestamps
      @timestamps ||= statuses.map { |status| status.fetch("captured_at") }.uniq.sort
    end

    def regions
      @regions ||= statuses.map { |status| status.fetch("region_id") }.uniq.sort
    end

    def status_for(region_id, timestamp)
      @status_by_cell ||= statuses.to_h { |status| [[status.fetch("region_id"), status.fetch("captured_at")], status] }
      @status_by_cell[[region_id, timestamp]]
    end

    def label_width = 118
    def plot_width = 1080
    def row_height = 25
    def chart_height = (regions.length * row_height) + 44
    def cell_width = plot_width.to_f / timestamps.length

    def label(timestamp)
      Time.parse(timestamp).utc.strftime("%d %b %H:%M UTC")
    end

    def h(value)
      CGI.escapeHTML(value.to_s)
    end
  end
end
