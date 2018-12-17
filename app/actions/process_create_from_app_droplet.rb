require 'actions/process_create'

module VCAP::CloudController
  class ProcessCreateFromAppDroplet
    class ProcessTypesNotFound < StandardError
    end

    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
      @logger = Steno.logger('cc.action.process_create_from_app_droplet')
    end

    def create(app)
      @logger.info('process_current_droplet', guid: app.guid)

      unless app.droplet && app.droplet.process_types
        @logger.warn('no process_types found', guid: app.guid)
        raise ProcessTypesNotFound.new("Unable to create process types for this app's droplet. Please provide a droplet with valid process types.")
      end
      revision = RevisionModel.find(app: app, droplet: droplet)
      unless revision
        @logger.warn("no revision found for app #{app.guid} and droplet #{droplet.guid}")
        raise ProcessTypesNotFound.new("Unable to create process types for this app's droplet. Please create a revision for the current app/droplet pair.")
      end

      create_requested_processes(app, app.droplet.process_types, revision)
    end

    private

    def create_requested_processes(app, process_types, revision)
      @logger.debug('using the droplet process_types', guid: app.guid)

      process_types.each_key { |type| create_process(app, type.to_s, revision) }
    end

    def create_process(app, type, revision)
      if app.processes_dataset.where(type: type).count == 0
        ProcessCreate.new(@user_audit_info).create(app, { type: type, revision: revision })
      end
    end
  end
end
