require 'messages/base_message'
require 'messages/validators'

module VCAP::CloudController
  class BuildpackCreateMessage < BaseMessage
    register_allowed_keys [:name, :stack, :position, :enabled, :locked]

    validates :name,
      string: true,
      presence: true,
      allow_nil: false
  end
end
