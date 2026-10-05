# frozen_string_literal: true

require "cgi/escape"
require "erb"
require "time"

require_relative "availability_chart"

module RunpodGpuAvailability
  class Dashboard
    TEMPLATE_PATH = File.expand_path("../../views/dashboard.html.erb", __dir__)

    def initialize(product:, snapshot:, current:, current_regions:, history:, region_statuses:, snapshot_count:, last_error:, days:, snapshot_cadence:)
      @product = product
      @snapshot = snapshot
      @current = current
      @current_regions = current_regions
      @history = history
      @region_statuses = region_statuses
      @snapshot_count = snapshot_count
      @last_error = last_error
      @days = days
      @snapshot_cadence = snapshot_cadence
    end

    def render
      ERB.new(File.read(TEMPLATE_PATH), trim_mode: "-").result(binding)
    end

    private

    attr_reader :product, :snapshot, :current, :current_regions, :history, :region_statuses, :snapshot_count, :last_error, :days, :snapshot_cadence

    def captured_at
      Time.parse(snapshot.fetch("captured_at")).utc.iso8601
    end

    def status_message
      return "No successful snapshot yet." unless snapshot

      "Captured #{captured_at} · #{snapshot_count} snapshots retained."
    end

    def h(value)
      CGI.escapeHTML(value.to_s)
    end

    def price(value)
      value ? format("$%.2f", value) : "—"
    end
  end
end
