# frozen_string_literal: true

require 'cgi/escape'
require 'erb'
require 'time'

require_relative 'availability_chart'

module RunpodGpuAvailability
  class Dashboard
    TEMPLATE_PATH = File.expand_path('../../views/dashboard.html.erb', __dir__)

    def initialize(snapshot:, current_regions:, historical:, snapshot_count:, latest_capture_run:, days:)
      @snapshot = snapshot
      @current_regions = current_regions
      @region_statuses = historical.fetch(:region_statuses)
      @region_availability_summaries = historical.fetch(:region_availability_summaries)
      @snapshot_count = snapshot_count
      @latest_capture_run = latest_capture_run
      @days = days
    end

    def render = ERB.new(File.read(TEMPLATE_PATH), trim_mode: '-').result(binding)

    private

    attr_reader :snapshot, :current_regions, :region_statuses, :region_availability_summaries, :snapshot_count,
                :latest_capture_run, :days

    def captured_at
      Time.parse(snapshot.fetch('captured_at')).utc.iso8601
    end

    def latest_capture_run_at
      timestamp = latest_capture_run.fetch('finished_at') || latest_capture_run.fetch('started_at')
      Time.parse(timestamp).utc.iso8601
    end

    def latest_capture_run_message
      return 'No collector run recorded yet.' unless latest_capture_run

      "Latest collector run: #{latest_capture_run.fetch('status')} at #{latest_capture_run_at}."
    end

    def latest_capture_error = latest_capture_run&.fetch('error_message')

    def status_message
      return 'No successful snapshot yet.' unless snapshot

      "#{snapshot_count} snapshots retained."
    end

    def h(value)
      CGI.escapeHTML(value.to_s)
    end

    def price(value)
      value ? format('$%.2f', value) : '—'
    end

    def price_range(record)
      lowest = record['lowest_observed_price_usd_per_hour']
      highest = record['highest_observed_price_usd_per_hour']
      return '—' unless lowest && highest

      "#{price(lowest)} — #{price(highest)}"
    end
  end
end
