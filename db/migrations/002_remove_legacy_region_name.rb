# frozen_string_literal: true

Sequel.migration do
  up do
    if schema(:gpu_availabilities).any? { |column, _| column == :region_name }
      drop_column(:gpu_availabilities, :region_name)
    end
  end
end
