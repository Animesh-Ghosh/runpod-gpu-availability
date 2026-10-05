# frozen_string_literal: true

require "json"
require "rack"

require_relative "dashboard"

module RunpodGpuAvailability
  class DashboardEndpoint
    DASHBOARD_PATHS = ["/", "/.json", "/dashboard.html", "/dashboard.json", "/index.json"].freeze
    AVAILABILITY_GROUPS = %w[HIGH MEDIUM LOW UNKNOWN].freeze

    def initialize(database:, runner:, product:, snapshot_cadence:, clock: Time)
      @database = database
      @runner = runner
      @product = product
      @snapshot_cadence = snapshot_cadence
      @clock = clock
    end

    def call(environment)
      request = Rack::Request.new(environment)
      return not_found unless request.get? && DASHBOARD_PATHS.include?(request.path)

      data = dashboard_data(days: requested_days(request))
      return json(json_data(data)) if json_request?(request)

      body = Dashboard.new(**data, snapshot_cadence: @snapshot_cadence).render
      [200, { "content-type" => "text/html; charset=utf-8" }, [body]]
    end

    private

    def requested_days(request)
      Integer(request.params.fetch("days", "7"), exception: false).to_i.clamp(1, 90)
    end

    def dashboard_data(days:)
      since = @clock.now - (days * 24 * 60 * 60)
      snapshot, current = @database.current_availabilities(product: @product)
      {
        product: @product,
        snapshot: clean_row(snapshot),
        current: current.map { |row| clean_row(row) },
        current_regions: @database.current_region_statuses(product: @product).map { |row| clean_row(row) },
        history: @database.history(product: @product, since: since).map { |row| clean_row(row) },
        region_statuses: @database.region_statuses(product: @product, since: since).map { |row| clean_row(row) },
        snapshot_count: @database.snapshot_count(product: @product),
        last_error: @runner.last_error,
        days: days
      }
    end

    def clean_row(row)
      row&.each_with_object({}) { |(key, value), result| result[key] = value if key.is_a?(String) }
    end

    def json_data(data)
      grouped_current = AVAILABILITY_GROUPS.to_h do |availability|
        [availability.downcase, { regions: [], configurations: [] }]
      end
      data.fetch(:current_regions).each do |region|
        grouped_current.fetch(availability_key(region))[:regions] << region
      end
      data.fetch(:current).each do |configuration|
        grouped_current.fetch(availability_key(configuration))[:configurations] << configuration
      end

      data.except(:current, :current_regions).merge(current: grouped_current)
    end

    def availability_key(record)
      availability = record.fetch("availability", "UNKNOWN").upcase
      AVAILABILITY_GROUPS.include?(availability) ? availability.downcase : "unknown"
    end

    def json_request?(request)
      request.path.end_with?(".json") || request.params["format"] == "json" ||
        request.get_header("HTTP_ACCEPT").to_s.include?("application/json")
    end

    def json(data)
      [200, { "content-type" => "application/json; charset=utf-8" }, [JSON.generate(data)]]
    end

    def not_found
      [404, { "content-type" => "text/plain" }, ["Not found\n"]]
    end
  end
end
