Sequel.migration do
  change do
    alter_table(:revisions) do
      add_column :version, Integer, default: 1
    end
  end
end
