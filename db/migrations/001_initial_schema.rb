# frozen_string_literal: true

Sequel.migration do
  up do
    create_table?(:snapshots) do
      primary_key :id
      String :captured_at, null: false
      String :product, null: false
    end

    create_table?(:gpu_availabilities) do
      primary_key :id
      foreign_key :snapshot_id, :snapshots, null: false, on_delete: :cascade
      String :region_id, null: false
      String :gpu_id, null: false
      String :gpu_name, null: false
      String :pool
      Integer :vram_gb
      String :availability, null: false
      Float :serverless_price_usd_per_hour
    end

    unless indexes(:snapshots).key?(:snapshots_product_captured_at)
      add_index(:snapshots, %i[product captured_at],
                name: :snapshots_product_captured_at)
    end
    unless indexes(:gpu_availabilities).key?(:gpu_availabilities_snapshot_id)
      add_index(:gpu_availabilities, :snapshot_id,
                name: :gpu_availabilities_snapshot_id)
    end
  end
end
