module VCAP::CloudController
  class BuildpackUpload
    class InvalidBuildpack < StandardError;
    end

    class NonUniqueStackAndName < StandardError;
    end

    def upload_async(message:, buildpack:, config:)
      logger.info("uploading buildpacks bits for buildpack #{buildpack.guid}")

      validator.validate(buildpack, message)

      upload_job = Jobs::V3::BuildpackBits.new(buildpack.guid, message.bits_path, message.bits_name)
      enqueued_job = Jobs::Enqueuer.new(upload_job, queue: Jobs::LocalQueue.new(config)).enqueue

      enqueued_job
    rescue Sequel::ValidationFailed => e
      raise InvalidBuildpack.new(e.message)
    end

    private

    def config
      VCAP::CloudController::Config.config
    end

    def logger
      @logger ||= Steno.logger('cc.action.buildpack_upload')
    end

    def validator
      Buildpacks::InstallValidations::UploadValidator
    end

    def validate_buildpack(buildpack, message)
      detected_stack = Buildpacks::StackNameExtractor.extract_from_file(bits_file_path: message.bits_path)
      existing_buildpacks = Buildpack.where(name: buildpack.name)

      if existing_buildpacks.any? { |bp| bp.stack == detected_stack && bp.guid != buildpack.guid }
        raise NonUniqueStackAndName
      end

      if detected_stack.nil?
        raise Jobs::Runtime::BuildpackInstallerFactory::StacklessBuildpackIncompatibilityError
      end
    end
  end
end
