require 'spec_helper'
require 'cloud_controller/buildpacks/install_validations/upload_validator'

module VCAP::CloudController
  module Buildpacks::InstallValidations
    RSpec.describe UploadValidator do
      describe '#validate' do
        let!(:buildpack) {VCAP::CloudController::Buildpack.create_from_hash({name: 'upload_binary_buildpack', stack: nil, position: 0})}
        let(:message) {BuildpackUploadMessage.new({'bits_path' => '/tmp/path', 'bits_name' => 'buildpack.zip'})}
        context 'when the buildpack is invalid' do
          describe 'stacks' do
            context 'when multiple buildpacks with the same name exist in the DB' do
              before do
                Buildpack.make(name: 'upload_binary_buildpack', stack: Stack.make(name: 'existing-stack').name)
                Buildpack.make(name: 'upload_binary_buildpack', stack: Stack.make(name: 'another-stack').name)
              end

              context 'when the uploaded buildpack’s detected stack is nil' do
                before do
                  allow(Buildpacks::StackNameExtractor).to receive(:extract_from_file).and_return(nil)
                end

                it 'raises a StacklessBuildpackIncompatibilityError' do
                  expect do
                    described_class.validate(buildpack, message)
                  end.to raise_error(Jobs::Runtime::BuildpackInstallerFactory::StacklessBuildpackIncompatibilityError)
                end
              end

              context 'when the uploaded buildpack’s detected stack is not nil' do
                context 'but there is already a buildpack with the same name/stack pair' do
                  before do
                    allow(Buildpacks::StackNameExtractor).to receive(:extract_from_file).and_return('existing-stack')
                  end

                  it 'raises' do
                    expect do
                      described_class.validate(buildpack, message)
                    end.to raise_error(UploadValidator::NonUniqueStackAndName)
                  end
                end
              end
            end
          end
        end
      end
    end
  end
end
