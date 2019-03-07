Sequel.migration do
  change do
    create_table :sidecars do
      VCAP::Migration.common(self)
      String :process_guid, size: 255
      String :command, size: 4096
    end
  end
end
