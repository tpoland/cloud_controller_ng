Sequel.migration do
  change do
    create_table(:revisions) do
      VCAP::Migration.common(self)
      String :deployment_guid, size: 255
      foreign_key [:deployment_guid], :deployments, key: :guid, name: :fk_deployment_revision_guid
      index [:deployment_guid], name: :fk_deployment_revision_guid_index
    end

    alter_table(:deployments) do
      add_column :revision_guid, String, size: 255
    end
  end

end
