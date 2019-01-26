require 'presenters/v3/app_environment_variables_presenter'
require 'presenters/v3/base_presenter'

module VCAP::CloudController
  module Presenters
    module V3
      class RevisionEnvironmentVariablesPresenter
        attr_reader :revision

        def initialize(revision)
          @revision = revision
        end

        def to_hash
          result = { var: {} }

          AppEnvironmentVariablesPresenter.populate_var(result, revision&.environment_variables)
        end
      end
    end
  end
end
