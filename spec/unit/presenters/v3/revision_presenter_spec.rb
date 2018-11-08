require 'spec_helper'
require 'presenters/v3/revision_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe RevisionPresenter do
    let(:deployment) {Deployment.make}
    let(:revision) {VCAP::CloudController::RevisonModel.make(deployment)}

    describe '#to_hash' do
      it 'presents the revision as json' do
        result = AppPresenter.new(revision).to_hash
        links = {
          self: { href: "#{link_prefix}/v3/apps/#{app.guid}/revisions/:#{revision.guid}" },
        }

        expect(result[:guid]).to eq(result.guid)
        expect(result[:created_at]).to be_a(Time)
        expect(result[:updated_at]).to be_a(Time)
        expect(result[:links]).to eq(links)
      end
    end
  end
end