# frozen_string_literal: true

require 'sequel'

module RunpodGpuAvailability
  class AvailabilityRepository
    def initialize(path:)
      @database = Sequel.sqlite(path, timeout: 5_000)
      @database.run('PRAGMA foreign_keys = ON')
    end

    def record_snapshot!(captured_at:, product:, catalog:)
      @database.transaction { insert_snapshot!(captured_at:, product:, catalog:) }
    end

    def start_capture!(product:, started_at:)
      capture_runs.insert(product:, started_at: started_at.utc.iso8601, status: 'running')
    end

    def complete_capture!(run_id:, captured_at:, product:, catalog:, finished_at:)
      @database.transaction do
        snapshot_id = insert_snapshot!(captured_at:, product:, catalog:)
        capture_runs.where(id: run_id, status: 'running').update(
          status: 'succeeded', snapshot_id:, finished_at: finished_at.utc.iso8601
        )
        snapshot_id
      end
    end

    def fail_capture!(run_id:, error_message:, finished_at:)
      capture_runs.where(id: run_id, status: 'running').update(
        status: 'failed', error_message:, finished_at: finished_at.utc.iso8601
      )
    end

    def fail_abandoned_captures!(finished_at:)
      capture_runs.where(status: 'running').update(
        status: 'failed',
        error_message: 'collector exited before completing this capture',
        finished_at: finished_at.utc.iso8601
      )
    end

    def prune_capture_runs!(before:)
      capture_runs.exclude(status: 'running').where { finished_at < before.utc.iso8601 }.delete
    end

    def latest_capture_run(product:)
      row(capture_runs.where(product:).order(Sequel.desc(:started_at)).first)
    end

    def latest_snapshot(product:)
      row(snapshots.where(product:).order(Sequel.desc(:captured_at)).first)
    end

    def current_availabilities(product:)
      snapshot = latest_snapshot(product:)
      return [nil, []] unless snapshot

      [snapshot, rows(current_availabilities_dataset(snapshot:))]
    end

    def current_region_statuses(product:)
      snapshot = latest_snapshot(product:)
      return [] unless snapshot

      rank = availability_rank
      rows(
        availabilities
          .where(snapshot_id: snapshot.fetch('id'))
          .select(
            :region_id,
            availability_name(Sequel.function(:max, rank)).as(:availability),
            availability_name(Sequel.function(:min, rank)).as(:worst_availability),
            Sequel.function(:count, Sequel.lit('*')).as(:advertised_configurations),
            Sequel.function(:min, :serverless_price_usd_per_hour).as(:last_observed_price_usd_per_hour)
          )
          .group(:region_id)
          .order(Sequel.desc(Sequel.function(:max, rank)), :region_id)
      )
    end

    def history(product:, since:)
      rows(history_dataset(product:, since:))
    end

    def region_price_ranges(product:, since:)
      rows(
        availability_with_snapshots(product:, since:)
          .select(
            Sequel[:a][:region_id],
            Sequel.function(:min, Sequel[:a][:serverless_price_usd_per_hour]).as(:lowest_observed_price_usd_per_hour),
            Sequel.function(:max, Sequel[:a][:serverless_price_usd_per_hour]).as(:highest_observed_price_usd_per_hour)
          )
          .group(Sequel[:a][:region_id])
      )
    end

    def region_statuses(product:, since:)
      rows(region_status_dataset(product:, since:))
    end

    def region_availability_summaries(product:, since:)
      rows(region_availability_summary_dataset(product:, since:))
    end

    def snapshot_count(product:)
      snapshots.where(product:).count
    end

    def close = @database.disconnect

    private

    def snapshots = @database[:snapshots]

    def availabilities = @database[:gpu_availabilities]

    def capture_runs = @database[:capture_runs]

    def insert_snapshot!(captured_at:, product:, catalog:)
      snapshot_id = snapshots.insert(captured_at: captured_at.utc.iso8601, product:)
      availabilities.multi_insert(availability_rows(snapshot_id:, catalog:))
      snapshot_id
    end

    def availability_rows(snapshot_id:, catalog:)
      catalog.fetch('gpus').flat_map do |gpu|
        Array(gpu['dataCenters']).map do |data_center|
          {
            snapshot_id:,
            region_id: data_center.fetch('id'),
            gpu_id: gpu.fetch('id'),
            gpu_name: gpu.fetch('name'),
            pool: gpu['pool'],
            vram_gb: gpu['memory'],
            availability: data_center['availability'] || gpu['availability'] || 'UNKNOWN',
            serverless_price_usd_per_hour: gpu.dig('price', 'serverless')
          }
        end
      end
    end

    def availability_with_snapshots(product:, since:)
      @database.from(Sequel.as(:gpu_availabilities, :a))
               .join(Sequel.as(:snapshots, :s), id: :snapshot_id)
               .where(Sequel[:s][:product] => product)
               .where { Sequel[:s][:captured_at] >= since.utc.iso8601 }
    end

    def current_availabilities_dataset(snapshot:)
      availabilities.where(snapshot_id: snapshot.fetch('id')).order(
        Sequel.desc(availability_rank),
        :region_id,
        :serverless_price_usd_per_hour,
        :gpu_name
      )
    end

    def history_dataset(product:, since:)
      availability_with_snapshots(product:, since:)
        .select(*history_columns)
        .group(*history_group)
        .order(*history_order)
    end

    def history_columns
      [
        Sequel[:a][:region_id],
        Sequel[:a][:gpu_name],
        Sequel[:a][:pool],
        Sequel[:a][:vram_gb],
        Sequel.function(:min, Sequel[:a][:serverless_price_usd_per_hour]).as(:lowest_price_usd_per_hour),
        Sequel.function(:count, Sequel.lit('*')).as(:observations),
        availability_count('HIGH').as(:high_observations),
        availability_count('MEDIUM').as(:medium_observations),
        availability_count('LOW').as(:low_observations),
        Sequel.function(:max, Sequel[:s][:captured_at]).as(:last_seen_at)
      ]
    end

    def history_group
      [
        Sequel[:a][:region_id], Sequel[:a][:gpu_id], Sequel[:a][:gpu_name], Sequel[:a][:pool], Sequel[:a][:vram_gb]
      ]
    end

    def history_order
      [
        Sequel.desc(:high_observations), Sequel.desc(:medium_observations), Sequel.desc(:low_observations),
        :lowest_price_usd_per_hour, Sequel[:a][:region_id], Sequel[:a][:gpu_name]
      ]
    end

    def region_status_dataset(product:, since:)
      availability_with_snapshots(product:, since:)
        .select(*region_status_columns)
        .group(Sequel[:s][:id], Sequel[:a][:region_id])
        .order(Sequel[:s][:captured_at], Sequel[:a][:region_id])
    end

    def region_status_columns
      rank = availability_rank(Sequel[:a][:availability])
      [
        Sequel[:s][:captured_at],
        Sequel[:a][:region_id],
        availability_name(Sequel.function(:max, rank)).as(:availability),
        Sequel.function(:count, Sequel.lit('*')).as(:advertised_configurations)
      ]
    end

    def region_availability_summary_dataset(product:, since:)
      region_snapshots = region_snapshots_dataset(product:, since:)
      @database.from(region_snapshots.as(:region_snapshots))
               .select(*region_summary_columns)
               .group(:region_id)
               .order(:region_id)
    end

    def region_snapshots_dataset(product:, since:)
      rank = availability_rank(Sequel[:a][:availability])
      availability_with_snapshots(product:, since:)
        .select(
          Sequel[:a][:region_id],
          Sequel[:s][:id].as(:snapshot_id),
          Sequel.function(:max, rank).as(:availability_rank)
        )
        .group(Sequel[:s][:id], Sequel[:a][:region_id])
    end

    def region_summary_columns
      [
        :region_id,
        Sequel.function(:count, Sequel.lit('*')).as(:snapshots_observed),
        rank_count(3).as(:high_snapshots),
        rank_count(2).as(:medium_snapshots),
        rank_count(1).as(:low_snapshots),
        rank_count(0).as(:unknown_snapshots),
        availability_name(Sequel.function(:max, :availability_rank)).as(:best_availability),
        availability_name(Sequel.function(:min, :availability_rank)).as(:worst_availability)
      ]
    end

    def availability_rank(column = :availability)
      Sequel.case({ 'HIGH' => 3, 'MEDIUM' => 2, 'LOW' => 1 }, 0, column)
    end

    def availability_name(rank)
      Sequel.case({ 3 => 'HIGH', 2 => 'MEDIUM', 1 => 'LOW' }, 'UNKNOWN', rank)
    end

    def availability_count(availability)
      Sequel.function(:sum, Sequel.case({ availability => 1 }, 0, Sequel[:a][:availability]))
    end

    def rank_count(rank)
      Sequel.function(:sum, Sequel.case({ rank => 1 }, 0, :availability_rank))
    end

    def row(record) = record&.transform_keys(&:to_s)

    def rows(dataset) = dataset.all.map { |record| row(record) }
  end
end
