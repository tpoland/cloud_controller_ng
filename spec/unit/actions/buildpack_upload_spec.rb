require 'spec_helper'
require 'actions/buildpack_upload'

module VCAP::CloudController
  RSpec.describe BuildpackUpload do
    subject(:buildpack_upload) { BuildpackUpload.new }

    describe '#upload_async' do
      let!(:buildpack) {VCAP::CloudController::Buildpack.create_from_hash({ name: 'upload_binary_buildpack', stack: nil, position: 0 })}
      let(:message) { PackageUploadMessage.new({ 'bits_path' => '/tmp/path' }) }
      let(:config) { Config.new({ name: 'local', index: '1' }) }
      let(:user_guid) { 'gooid' }
      let(:user_email) { 'eli.loves@dogs.com' }
      let(:user_audit_info) { UserAuditInfo.new(user_email: user_email, user_guid: user_guid) }

      it 'enqueues and returns an upload job' do
        returned_job = nil
        expect {
          returned_job = buildpack_upload.upload_async(message: message, buildpack: buildpack, user_audit_info: user_audit_info)
        }.to change { Delayed::Job.count }.by(1)

        job = Delayed::Job.last
        expect(returned_job).to eq(job)
        expect(job.queue).to eq('cc-local-1')
        expect(job.handler).to include(buildpack.guid)
        expect(job.handler).to include('BuildpackBits')
      end

      it 'leaves the state as AWAITING_UPLOAD' do
        buildpack_upload.upload_async(message: message, buildpack: buildpack, user_audit_info: user_audit_info)
        expect(Buildpack.find(guid: buildpack.guid).state).to eq(Buildpack::CREATED_STATE)
      end


      context 'when the buildpack is invalid' do
      end
    end
  end
end
