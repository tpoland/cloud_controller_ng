require 'spec_helper'
require 'presenters/v3/revision_environment_variables_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RevisionEnvironmentVariablesPresenter do
    let(:revision) do
      VCAP::CloudController::RevisionModel.make(
        environment_variables: { 'CUSTOM_ENV_VAR' => 'hello' },
      )
    end

    subject(:presenter) { RevisionEnvironmentVariablesPresenter.new(revision) }

    describe '#to_hash' do
      let(:result) { presenter.to_hash }

      it 'presents the app environment variables as json' do
        expect(result).to eq({
          var: {
            CUSTOM_ENV_VAR: 'hello'
          }
        })
      end

      # TODO: LINK back to revision plz
    end
  end
end
