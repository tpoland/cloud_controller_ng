Sequel.migration do
  change do
    add_column :apps, :current_revision_version, Integer, default: 0
  end
end
