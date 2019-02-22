Sequel.migration do
  change do
    create_table :revision_process_commands do
      VCAP::Migration.common(self)
      String :revision_guid, size: 255, null: false
      index :revision_guid, name: :rev_commands_revision_guid_index
      foreign_key [:revision_guid], :revisions, key: :guid, name: :rev_commands_revision_guid_fkey
      String :process_type, size: 255, null: false
      # the size of this string column is set to 5000 as it may be slightly larger than the source
      # due to being encrypted
      String :encrypted_process_command, size: 5000, null: false
      String :salt, size: 255
      String :encryption_key_label, size: 255
    end
  end
end
