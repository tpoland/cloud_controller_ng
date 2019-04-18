Sequel.migration do
  change do
    alter_table(:users) do
      add_column :is_client, :boolean, default: nil, null: true
    end
  end
end
