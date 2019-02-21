Sequel.migration do
  change do
    alter_table(:packages) do
      add_column :encryption_iterations, Integer, default: 2048
    end
  end
end
