require 'spec_helper'
require 'messages/buildpack_create_message'

module VCAP::CloudController
  RSpec.describe BuildpackCreateMessage do
    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}
        it 'is not valid' do
          message = BuildpackCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors[:name]).to include("can't be blank")
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) do
          {
            unexpected: 'meow',
            name: 'the-name'
          }
        end

        it 'is not valid' do
          message = BuildpackCreateMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end
    end
  end
end
