Sequel.migration do
  up do
    alter_table :app_annotations do
      set_column_type :resource_guid, String, size: 255
    end
  end

  down do
    alter_table :app_annotations do
      set_column_type :resource_guid, String, size: 255
    end
  end
end
