module VCAP::CloudController
  class SidecarProcessTypeModel < Sequel::Model(:sidecar_process_types)
    many_to_one :sidecar,
      class: 'VCAP::CloudController::SidecarModel',
      key: :sidecar_guid,
      primary_key: :guid,
      without_guid_generation: true

  end
end
