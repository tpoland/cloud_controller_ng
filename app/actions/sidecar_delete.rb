module VCAP::CloudController
  class SidecarDelete
    def initialize(user_audit_info)
      @user_audit_info = user_audit_info
    end

    # TODO: backfill tests

    def delete(sidecars)
      sidecars = Array(sidecars)

      sidecars.each do |sidecar|
        sidecar.db.transaction do
          sidecar.lock!
          sidecar.sidecar_process_types.map(&:destroy)
          sidecar.destroy
        end
      end
    end

    private

    def delete_metadata(res)
      LabelDelete.delete(res.labels)
      AnnotationDelete.delete(res.annotations)
    end
  end
end
