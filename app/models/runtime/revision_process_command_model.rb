module VCAP::CloudController
  class RevisionProcessCommandModel < Sequel::Model(:revision_process_commands)

    set_field_as_encrypted :process_command, column: :encrypted_process_command
  end
end
