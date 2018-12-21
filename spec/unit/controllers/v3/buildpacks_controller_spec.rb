require 'rails_helper'
require 'messages/buildpack_create_message'
require 'models/runtime/buildpack'
require 'spec_helper'

RSpec.describe BuildpacksController, type: :controller do
  describe '#create' do
    before do
      VCAP::CloudController::Buildpack.make
      VCAP::CloudController::Buildpack.make
      VCAP::CloudController::Buildpack.make
    end

    context 'when authorized' do
      let(:user) { VCAP::CloudController::User.make }
      let(:stack) { VCAP::CloudController::Stack.make }
      let(:params) do
        {
          name: 'the-r3al_Name',
          stack: stack.name,
          position: 2,
          enabled: false,
          locked: true,
        }
      end

      before do
        set_current_user_as_admin(user: user)
      end

      context 'when params are correct' do
        context 'when the stack exists' do
          let(:stack) { VCAP::CloudController::Stack.make }

          it 'should save the buildpack in the database' do
            post :create, params: params, as: :json

            buildpack_id = parsed_body['guid']
            our_buildpack = VCAP::CloudController::Buildpack.find(guid: buildpack_id)
            expect(our_buildpack).to_not be_nil
            expect(our_buildpack.name).to eq(params[:name])
            expect(our_buildpack.stack).to eq(params[:stack])
            expect(our_buildpack.position).to eq(params[:position])
            expect(our_buildpack.enabled).to eq(params[:enabled])
            expect(our_buildpack.locked).to eq(params[:locked])
          end
        end

        context 'when the stack does not exist' do
          let(:stack) { double(:stack, name: 'does-not-exist') }

          it 'does not create the buildpack' do
            expect { post :create, params: params, as: :json }.
              to_not change { VCAP::CloudController::Buildpack.count }
          end

          it 'returns 422' do
            post :create, params: params, as: :json

            expect(response.status).to eq 422
          end

          it 'returns a helpful error message' do
            post :create, params: params, as: :json

            expect(parsed_body['errors'][0]['detail']).to include("Stack '#{stack.name}' does not exist")
          end
        end
      end

      context 'when params are invalid' do
        before do
          allow_any_instance_of(VCAP::CloudController::BuildpackCreateMessage).
            to receive(:valid?).and_return(false)
        end

        it 'returns 422' do
          post :create, params: params, as: :json

          expect(response.status).to eq 422
        end

        it 'does not create the buildpack' do
          expect { post :create, params: params, as: :json }.
            to_not change { VCAP::CloudController::Buildpack.count }
        end
      end
    end
  end

  describe '#show' do
    let(:user) { VCAP::CloudController::User.make }

    before do
      set_current_user(user)
    end

    context 'when the buildpack exists' do
      let(:buildpack) { VCAP::CloudController::Buildpack.make }
      it 'renders a single buildpack details' do
        get :show, params: { guid: buildpack.guid }
        expect(response.status).to eq 200
        expect(parsed_body['guid']).to eq(buildpack.guid)
      end
    end

    context 'when the buildpack does not exist' do
      it 'errors' do
        get :show, params: { guid: 'psych!' }
        expect(response.status).to eq 404
        expect(response.body).to include('ResourceNotFound')
      end
    end
  end

  describe '#upload' do
    let(:test_buildpack) {VCAP::CloudController::Buildpack.create_from_hash({ name: 'upload_binary_buildpack', stack: nil, position: 0 })}
    let(:user) { VCAP::CloudController::User.make }

    describe 'permissions by role' do
      role_to_expected_http_response = {
        'admin' => 200,
        'space_developer' => 403,
        'space_manager' => 403,
        'space_auditor' => 403,
        'org_manager' => 403,
        'admin_read_only' => 403,
        'global_auditor' => 403,
        'org_auditor' => 403,
        'org_billing_manager' => 403,
        'org_user' => 403,
      }.freeze

      role_to_expected_http_response.each do |role, expected_return_value|
        context "as an #{role}" do
          let(:org) { VCAP::CloudController::Organization.make }
          let(:space) { VCAP::CloudController::Space.make(organization: org) }

          it "returns #{expected_return_value}" do
            set_current_user_as_role(role: role, org: org, space: space, user: user)

            post :upload, params: {guid: test_buildpack.guid}

            expect(response.status).to eq expected_return_value
          end
        end
      end

      it 'returns 401 when logged out' do
        post :upload, params: {guid: test_buildpack.guid}

        expect(response.status).to eq 401
      end
    end

    describe 'when the user is logged in and has permissions' do

      let(:filename) { 'file.zip' }
      let(:sha_valid_zip) { Digester.new(algorithm: Digest::SHA256).digest_file(valid_zip) }
      let(:sha_valid_zip2) { Digester.new(algorithm: Digest::SHA256).digest_file(valid_zip2) }
      let(:sha_valid_tar_gz) { Digester.new(algorithm: Digest::SHA256).digest_file(valid_tar_gz) }

      let(:valid_zip_manifest_tmpdir) { Dir.mktmpdir }
      let(:valid_zip_manifest) do
        zip_name = File.join(valid_zip_manifest_tmpdir, filename)
        TestZip.create(zip_name, 1, 1024) do |zipfile|
          zipfile.get_output_stream('manifest.yml') do |f|
            f.write("---\nstack: stack-from-manifest\n")
          end
        end
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:valid_zip_unknown_stack_tmpdir) { Dir.mktmpdir }
      let(:valid_zip_unknown_stack) do
        zip_name = File.join(valid_zip_unknown_stack_tmpdir, filename)
        TestZip.create(zip_name, 1, 1024) do |zipfile|
          zipfile.get_output_stream('manifest.yml') do |f|
            f.write("---\nstack: unknown-stack\n")
          end
        end
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:valid_zip_tmpdir) { Dir.mktmpdir }
      let!(:valid_zip) do
        zip_name = File.join(valid_zip_tmpdir, filename)
        TestZip.create(zip_name, 1, 1024)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:valid_zip_copy_tmpdir) { Dir.mktmpdir }
      let!(:valid_zip_copy) do
        zip_name = File.join(valid_zip_copy_tmpdir, filename)
        FileUtils.cp(valid_zip.path, zip_name)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:valid_zip2_tmpdir) { Dir.mktmpdir }
      let!(:valid_zip2) do
        zip_name = File.join(valid_zip2_tmpdir, filename)
        TestZip.create(zip_name, 3, 1024)
        zip_file = File.new(zip_name)
        Rack::Test::UploadedFile.new(zip_file)
      end

      let(:valid_tar_gz_tmpdir) { Dir.mktmpdir }
      let(:valid_tar_gz) do
        tar_gz_name = File.join(valid_tar_gz_tmpdir, 'file.tar.gz')
        TestZip.create(tar_gz_name, 1, 1024)
        tar_gz_name = File.new(tar_gz_name)
        Rack::Test::UploadedFile.new(tar_gz_name)
      end

      let(:upload_body) { { buildpack: valid_zip, buildpack_name: valid_zip.path } }

      before do
        set_current_user_as_admin(user: user)
        CloudController::DependencyLocator.instance.register(:upload_handler, UploadHandler.new(TestConfig.config_instance))
        TestConfig.override(directories: { tmpdir: File.dirname(valid_zip.path) })
        @cache = Delayed::Worker.delay_jobs
        Delayed::Worker.delay_jobs = false

        VCAP::CloudController::Stack.make(name: 'stack')
        VCAP::CloudController::Stack.make(name: 'stack-from-manifest')
      end
      after do
        FileUtils.rm_rf(valid_zip_manifest_tmpdir)
        FileUtils.rm_rf(valid_zip_unknown_stack_tmpdir)
        FileUtils.rm_rf(valid_zip_tmpdir)
        FileUtils.rm_rf(valid_zip_copy_tmpdir)
        FileUtils.rm_rf(valid_zip2_tmpdir)
        FileUtils.rm_rf(valid_tar_gz_tmpdir)
      end

      context 'When the upload is valid' do
        it 'gets the uploaded file from the upload handler' do
          upload_handler = CloudController::DependencyLocator.instance.upload_handler
          expect(upload_handler).to receive(:uploaded_file).with(hash_including('buildpack_name' => filename), 'buildpack').and_return(valid_zip)
          post :upload, params: upload_body.merge(guid: test_buildpack.guid)
        end
      end


    end
  end
end

