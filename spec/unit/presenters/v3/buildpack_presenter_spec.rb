require 'spec_helper'
require 'presenters/v3/buildpack_presenter'

RSpec.describe VCAP::CloudController::Presenters::V3::BuildpackPresenter do
  let(:buildpack) {VCAP::CloudController::Buildpack.make}

  describe '#to_hash' do
    let(:result) {described_class.new(can_upload, buildpack).to_hash}

    describe 'links' do
      context 'when bits service is disabled' do
        it 'has self and upload links' do
          expect(result[:links][:upload][:href]).to eq("#{link_prefix}/v3/buildpacks/#{buildpack.guid}/upload")
          expect(result[:links][:upload][:method]).to eq('POST')
          expect(result[:links][:self][:href]).to eq("#{link_prefix}/v3/buildpacks/#{buildpack.guid}")
        end
      end

      context 'when bits service is enabled' do
        before do
          TestConfig.override(
            bits_service: {
              enabled: true,
              public_endpoint: 'http://my-endpoint.com',
              username: 'username',
              password: 'password',
              signing_key_secret: 'random-key-secret',
              signing_key_id: 'key-id',
              private_endpoint: 'http://private-endpoint.com',
            }
          )
        end

        context 'when the user does not have write permission' do
          let(:can_upload) { false }

          it 'does not display an upload link' do
            expect(result[:links][:upload]).to be_nil
          end
        end

        context 'when the user does have write permissions' do
          let(:can_upload) { true }

          it 'does not display an upload link' do
            expect(result[:links][:upload][:method]).to eq('POST')
            expect(result[:links][:upload][:href]).to match(%r{http://my-endpoint\.com/buildpacks/\?signature=\w+&expires=\d+&AccessKeyId=key-id&async=true&verb=put})
          end
        end
      end
    end

    context 'when optional fields are present' do
      it 'presents the buildpack with those fields' do
        expect(result[:guid]).to eq(buildpack.guid)
        expect(result[:created_at]).to eq(buildpack.created_at)
        expect(result[:updated_at]).to eq(buildpack.updated_at)
        expect(result[:name]).to eq(buildpack.name)
        expect(result[:state]).to eq(buildpack.state)
        expect(result[:filename]).to eq(buildpack.filename)
        expect(result[:stack]).to eq(buildpack.stack)
        expect(result[:position]).to eq(buildpack.position)
        expect(result[:enabled]).to eq(buildpack.enabled)
        expect(result[:locked]).to eq(buildpack.locked)
      end
    end

    context 'when optional fields are missing' do
      before do
        buildpack.stack = nil
        buildpack.filename = nil
      end

      it 'still presents their keys with nil values' do
        expect(result.fetch(:stack)).to be_nil
      end

      it 'still presents all other values' do
        expect(result[:guid]).to eq(buildpack.guid)
        expect(result[:created_at]).to eq(buildpack.created_at)
        expect(result[:updated_at]).to eq(buildpack.updated_at)
        expect(result[:name]).to eq(buildpack.name)
        expect(result[:state]).to eq(buildpack.state)
        expect(result[:filename]).to eq(nil)
        expect(result[:position]).to eq(buildpack.position)
        expect(result[:enabled]).to eq(buildpack.enabled)
        expect(result[:locked]).to eq(buildpack.locked)
      end
    end
  end
end
