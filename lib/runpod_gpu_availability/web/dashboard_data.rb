# frozen_string_literal: true

module RunpodGpuAvailability
  module Web
    class DashboardData
      AVAILABILITY_GROUPS = %w[HIGH MEDIUM LOW UNKNOWN].freeze

      def initialize(repository:)
        @repository = repository
        @product = CatalogClient::PRODUCT
      end

      def html(days:)
        data = fetch(days:)
        data.slice(:snapshot, :current_regions, :snapshot_count, :latest_capture_run, :days).merge(
          historical: data.slice(:region_statuses, :region_availability_summaries)
        )
      end

      def json(days:)
        data = fetch(days:)
        data.except(:current, :current_regions).merge(current: grouped_current(data))
      end

      private

      def fetch(days:)
        since = Time.now - (days * 24 * 60 * 60)
        snapshot, current = @repository.current_availabilities(product: @product)
        summaries = @repository.region_availability_summaries(product: @product, since:)
        {
          product: @product,
          snapshot: clean_row(snapshot),
          current: current.map { |row| clean_row(row) },
          current_regions: current_regions(since:, configurations: current),
          history: @repository.history(product: @product, since:).map { |row| clean_row(row) },
          region_statuses: @repository.region_statuses(product: @product, since:).map { |row| clean_row(row) },
          region_availability_summaries: summaries.map { |row| clean_row(row) },
          snapshot_count: @repository.snapshot_count(product: @product),
          latest_capture_run: clean_row(@repository.latest_capture_run(product: @product)),
          days:
        }
      end

      def current_regions(since:, configurations:)
        price_ranges = observed_price_ranges(since:)
        @repository.current_region_statuses(product: @product).map do |row|
          region = clean_row(row)
          region_id = region.fetch('region_id')
          region.merge(
            price_ranges.fetch(region_id, {}),
            'configurations' => configurations.filter_map do |configuration|
              clean_row(configuration) if configuration.fetch('region_id') == region_id
            end
          )
        end
      end

      def observed_price_ranges(since:)
        @repository.region_price_ranges(product: @product, since:).to_h do |price_range|
          [price_range.fetch('region_id'), clean_row(price_range)]
        end
      end

      def grouped_current(data)
        grouped = AVAILABILITY_GROUPS.to_h do |availability|
          [availability.downcase, { regions: [], configurations: [] }]
        end
        data.fetch(:current_regions).each do |region|
          grouped.fetch(availability_key(region))[:regions] << region
        end
        data.fetch(:current).each do |configuration|
          grouped.fetch(availability_key(configuration))[:configurations] << configuration
        end
        grouped
      end

      def availability_key(record)
        availability = record.fetch('availability', 'UNKNOWN').upcase
        AVAILABILITY_GROUPS.include?(availability) ? availability.downcase : 'unknown'
      end

      def clean_row(row)
        row&.each_with_object({}) { |(key, value), result| result[key] = value if key.is_a?(String) }
      end
    end
  end
end
