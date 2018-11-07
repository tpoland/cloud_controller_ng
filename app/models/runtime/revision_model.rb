module VCAP::CloudController
  class RevisionModel < Sequel::Model(:revisions)
    many_to_one :deployment,
     class: '::VCAP::CloudController::DeploymentModel',
     key: :deployment_guid,
     primary_key: :guid,
     without_guid_generation: true
  end
end