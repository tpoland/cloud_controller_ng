Sequel.migration do
  change do
    alter_table(:service_bindings) do
      add_column :encryption_iterations, Integer, default: 2048
    end
  end
end
