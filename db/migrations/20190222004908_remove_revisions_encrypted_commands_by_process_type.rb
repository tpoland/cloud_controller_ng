Sequel.migration do
  up do
    alter_table(:revisions) do
      drop_column :encrypted_commands_by_process_type
    end
  end
  down do
    alter_table(:revisions) do
      add_column :encrypted_commands_by_process_type, String, size: 4096
    end
  end
end
