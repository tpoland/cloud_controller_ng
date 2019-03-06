# Generated by the protocol buffer compiler.  DO NOT EDIT!
# source: cells.proto

require 'google/protobuf'

require 'error_pb'
Google::Protobuf::DescriptorPool.generated_pool.build do
  add_message "diego.bbs.models.CellCapacity" do
    optional :memory_mb, :int32, 1
    optional :disk_mb, :int32, 2
    optional :containers, :int32, 3
  end
  add_message "diego.bbs.models.CellPresence" do
    optional :cell_id, :string, 1
    optional :rep_address, :string, 2
    optional :zone, :string, 3
    optional :capacity, :message, 4, "diego.bbs.models.CellCapacity"
    repeated :rootfs_providers, :message, 5, "diego.bbs.models.Provider"
    repeated :placement_tags, :string, 6
    repeated :optional_placement_tags, :string, 7
    optional :rep_url, :string, 8
  end
  add_message "diego.bbs.models.Provider" do
    optional :name, :string, 1
    repeated :properties, :string, 2
  end
  add_message "diego.bbs.models.CellsResponse" do
    optional :error, :message, 1, "diego.bbs.models.Error"
    repeated :cells, :message, 2, "diego.bbs.models.CellPresence"
  end
end

module Diego
  module Bbs
    module Models
      CellCapacity = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.CellCapacity").msgclass
      CellPresence = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.CellPresence").msgclass
      Provider = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.Provider").msgclass
      CellsResponse = Google::Protobuf::DescriptorPool.generated_pool.lookup("diego.bbs.models.CellsResponse").msgclass
    end
  end
end
