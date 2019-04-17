Sequel.migration do
  change do
    rename_table :apps, :tmp_apps

    alter_table :tmp_apps do
      add_index :name, name: :real_performant_apps_name_index
    end
    
    rename_table :tmp_apps, :apps
  end
end
