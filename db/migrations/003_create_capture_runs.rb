# frozen_string_literal: true

Sequel.migration do
  up do
    create_table?(:capture_runs) do
      primary_key :id
      String :product, null: false
      String :started_at, null: false
      String :finished_at
      String :status, null: false
      String :error_message
      foreign_key :snapshot_id, :snapshots, on_delete: :set_null
      check(Sequel.lit("status IN ('running', 'succeeded', 'failed')"))
    end

    unless indexes(:capture_runs).key?(:capture_runs_product_started_at)
      add_index(:capture_runs, %i[product started_at], name: :capture_runs_product_started_at)
    end
    unless indexes(:capture_runs).key?(:capture_runs_status)
      add_index(:capture_runs, :status, name: :capture_runs_status)
    end
  end
end
