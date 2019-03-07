module VCAP::CloudController
  class SidecarModel < Sequel::Model(:sidecars)
    many_to_one :processes,
      class: 'VCAP::CloudController::ProcessModel',
      primary_key: :guid,
      key: :process_guid,
      without_guid_generation: true
  end
end
