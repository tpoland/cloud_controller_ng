Sequel.migration do
  change do
    alter_table(:revisions) do
      add_column :version, Integer
    end
  end
end
