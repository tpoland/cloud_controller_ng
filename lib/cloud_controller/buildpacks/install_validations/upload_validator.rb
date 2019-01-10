module VCAP::CloudController
  module Buildpacks
    module InstallValidations
      class UploadValidator
        class NonUniqueStackAndName < StandardError
        end

        def self.validate(buildpack, message)
          db_buildpacks = Buildpack.where(name: buildpack.name).exclude(guid: buildpack.guid).all
          detected_stack = Buildpacks::StackNameExtractor.extract_from_file(bits_file_path: message.bits_path)

          raise Jobs::Runtime::BuildpackInstallerFactory::StacklessBuildpackIncompatibilityError unless does_not_rollback_Stack?

          raise NonUniqueStackAndName unless is_unique?
        end

        def is_unique?(db_buildpacks, detected_stack)
          db_buildpacks.select { |bp| bp.stack == detected_stack }.empty?
        end

        def does_not_rollback_stack?(db_buildpacks, detected_stack)
          detected_stack.nil? && db_buildpacks.empty?
        end
      end
    end
  end
end
