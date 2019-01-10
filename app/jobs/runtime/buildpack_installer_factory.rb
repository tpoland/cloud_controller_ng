module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackInstallerFactory
        ##
        # Raised when attempting to install two buildpacks with the same name and stack
        class DuplicateInstallError < StandardError
        end

        ##
        # Raised when attempting to install a buildpack without a stack,
        # but there is already an existing buildpack with a matching name
        # and has a non-nil stack.
        #
        # As an operator, you cannot regress to an older style buildpack
        # that has a nil stack.
        class StacklessBuildpackIncompatibilityError < StandardError
        end

        ##
        # Raised when attempting to install a buildpack,
        # but there are already existing buildpacks with matching names
        # and one has a nil `stack` and another has a non-nil `stack`.
        #
        # As an operator, you can resolve this by deleting the existing buildpack
        # that has a `stack` of nil.
        class StacklessAndStackfulMatchingBuildpacksExistError < StandardError
        end

        def plan(buildpack_name, manifest_fields)
          ensure_no_duplicate_buildpack_stacks!(manifest_fields)
          ensure_no_mix_of_stackless_and_stackful_buildpacks!(manifest_fields)

          planned_jobs = []

          found_buildpacks = Buildpack.where(name: buildpack_name).all


          manifest_fields.each do |buildpack_fields|
            detected_stack = buildpack_fields[:stack]

            if found_buildpacks.empty?
              planned_jobs << VCAP::CloudController::Jobs::Runtime::CreateBuildpackInstaller.new({
                name: buildpack_name,
                stack: buildpack_fields[:stack],
                file: buildpack_fields[:file],
                options: buildpack_fields[:options]
              })
              next
            end

            ensure_no_buildpack_downgraded_to_nil_stack!(found_buildpacks)

            buildpack_to_update = found_buildpacks.find {|candidate| candidate.stack == detected_stack}
            unless buildpack_to_update.nil?
              planned_jobs << VCAP::CloudController::Jobs::Runtime::UpdateBuildpackInstaller.new({
                name: buildpack_name,
                stack: buildpack_fields[:stack],
                file: buildpack_fields[:file],
                options: buildpack_fields[:options],
                upgrade_buildpack_guid: buildpack_to_update.guid
              })
              next
            end

            # prevent creation of a new buildpack with the same name, but a nil stack
            raise StacklessBuildpackIncompatibilityError if detected_stack.nil?

            buildpack_to_update = found_buildpacks.find {|candidate| candidate.stack.nil?}
            if buildpack_to_update && buildpack_not_yet_updated_from_nil_stack(planned_jobs, buildpack_to_update.guid)
              planned_jobs << VCAP::CloudController::Jobs::Runtime::UpdateBuildpackInstaller.new({
                name: buildpack_name,
                stack: buildpack_fields[:stack],
                file: buildpack_fields[:file],
                options: buildpack_fields[:options],
                upgrade_buildpack_guid: buildpack_to_update.guid
              })
              next
            end

            planned_jobs << VCAP::CloudController::Jobs::Runtime::CreateBuildpackInstaller.new({
              name: buildpack_name,
              stack: buildpack_fields[:stack],
              file: buildpack_fields[:file],
              options: buildpack_fields[:options]
            })

          end

          planned_jobs
        end

        ## we dont care about these
        # validate not planned
        def buildpack_not_yet_updated_from_nil_stack(planned_jobs, buildpack_guid)
          planned_jobs.none? {|job| job.guid_to_upgrade == buildpack_guid}
        end

        # validate the DB
        def ensure_no_buildpack_downgraded_to_nil_stack!(buildpacks)
          if buildpacks.size > 1 && buildpacks.any? {|b| b.stack.nil?}
            raise StacklessAndStackfulMatchingBuildpacksExistError
          end
        end

        # validate manifest stack combos
        def ensure_no_mix_of_stackless_and_stackful_buildpacks!(manifest_fields)
          if manifest_fields.size > 1 && manifest_fields.any? {|f| f[:stack].nil?}
            raise StacklessBuildpackIncompatibilityError
          end
        end

        # validate manifest uniqueness
        def ensure_no_duplicate_buildpack_stacks!(manifest_fields)
          if manifest_fields.uniq {|f| f[:stack]}.length < manifest_fields.length
            raise DuplicateInstallError
          end
        end
      end
    end
  end
end
