require 'repositories/package_event_repository'

module VCAP::CloudController
  class PackageCreate
    class InvalidPackage < StandardError; end

    class << self
      def create(message:, app:, user_audit_info:, record_event: true)
        Steno.logger('cc.action.package_create').info("creating package type #{message.type} for app #{message.app_guid}")

        verify_package_and_app_lifecycle_match!(message, app)

        package              = PackageModel.new
        package.app_guid     = app.guid
        package.type         = message.type
        package.state        = get_package_state(message)

        if message.docker_type?
          docker_data = message.docker_data
          package.docker_image = docker_data.image
          package.docker_username = docker_data.username
          package.docker_password = docker_data.password
        end

        package.db.transaction do
          package.save
          record_audit_event(package, message, user_audit_info) if record_event
          MetadataUpdate.update(package, message)
        end

        package
      rescue Sequel::ValidationFailed => e
        raise InvalidPackage.new(e.message)
      end

      def create_without_event(message, app)
        create(message: message, app: app, user_audit_info: UserAuditInfo.new(user_guid: nil, user_email: nil), record_event: false)
      end

      private

      def record_audit_event(package, message, user_audit_info)
        Repositories::PackageEventRepository.record_app_package_create(
          package,
          user_audit_info,
          message.audit_hash)
      end

      def get_package_state(message)
        message.bits_type? ? PackageModel::CREATED_STATE : PackageModel::READY_STATE
      end

      def verify_package_and_app_lifecycle_match!(message, app)
        if app.docker? && !message.docker_type?
          raise InvalidPackage.new("Cannot set package type to 'bits' for a docker app")
        elsif app.buildpack? && !message.bits_type?
          raise InvalidPackage.new("Cannot set package type to 'docker' for a buildpack app")
        end
      end
    end
  end
end
