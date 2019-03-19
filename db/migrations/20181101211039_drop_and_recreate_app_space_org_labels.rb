Sequel.migration do
  no_transaction
  up do
    # These tables were never present in a released capi-release so it is safe to drop them
    run 'drop table if exists app_labels;'
    create_table(:app_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :app_labels, :apps)
    end

    run 'drop table if exists organization_labels;'
    create_table(:organization_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :organization_labels, :organizations)
    end

    run 'drop table if exists space_labels;'
    create_table(:space_labels) do
      VCAP::Migration.common(self)
      VCAP::Migration.labels_common(self, :space_labels, :spaces)
    end
  end

  down do
    run 'drop table if exists organization_labels;'
    create_table(:organization_labels) do
      VCAP::Migration.common(self)

      String :org_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63

      foreign_key [:org_guid], :organizations, key: :guid, name: :fk_organization_labels_org_guid
      index [:org_guid], name: :fk_organization_labels_org_guid_index
      index [:key_prefix, :key_name, :value], name: :organization_labels_compound_index
    end

    run 'drop table if exists space_labels;'
    create_table(:space_labels) do
      VCAP::Migration.common(self)

      String :space_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63

      foreign_key [:space_guid], :spaces, key: :guid, name: :fk_space_labels_space_guid
      index [:space_guid], name: :fk_space_labels_space_guid_index
      index [:key_prefix, :key_name, :value], name: :space_labels_compound_index
    end

    run 'drop table if exists app_labels;'
    create_table(:app_labels) do
      VCAP::Migration.common(self)

      String :app_guid, size: 255
      String :key_prefix, size: 253
      String :key_name, size: 63
      String :value, size: 63

      foreign_key [:app_guid], :apps, key: :guid, name: :fk_app_labels_app_guid
      index [:app_guid], name: :fk_app_labels_app_guid_index
      index [:key_prefix, :key_name, :value], name: :app_labels_compound_index
    end
  end
end
