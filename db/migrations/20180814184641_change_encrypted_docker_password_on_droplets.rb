Sequel.migration do
  up do
    alter_table :droplets do
      set_column_type :encrypted_docker_receipt_password, String, size: 16_000
    end
  end
  down do
    alter_table :droplets do
      set_column_type :encrypted_docker_receipt_password, String, size: 16_000
    end
  end
end
