require 'spec_helper'
require 'messages/usage_events_list_message'

module VCAP::CloudController
  RSpec.describe UsageEventsListMessage do
    subject { UsageEventsListMessage.from_params(params) }
    let(:params) { {} }

    describe '.from_params' do
      it 'defaults the order_by param to created_at' do
        expect(subject.pagination_options.order_by).to eq('created_at')
      end
    end

    it 'accepts an empty set' do
      expect(subject).to be_valid
    end

    context 'when there are valid params' do
      let(:params) do
        {
          'types' => 'app,service',
          'guids' => 'guid5,guid6',
          'service_instance_types' => 'managed_service_instance',
          'service_offering_guids' => 'guid3,guid4',
        }
      end

      it 'accepts the params as valid' do
        expect(subject).to be_valid
      end
    end

    context 'when invalid params are given' do
      let(:params) { { foobar: 'pants' } }

      it 'does not accept any other params' do
        expect(subject).not_to be_valid
        expect(subject.errors[:base][0]).to include("Unknown query parameter(s): 'foobar'")
      end
    end

    context 'validations' do
      context 'when the types filter is provided' do
        let(:params) { { 'types' => 'app,service' } }

        context 'and the values are invalid' do
          let(:params) { { types: false } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:types]).to include('must be an array')
          end
        end

        it 'sets the message types to the provided values' do
          expect(subject).to be_valid
          expect(subject.types).to eq(['app', 'service'])
        end
      end

      context 'when the guids filter is provided' do
        let(:params) { { 'guids' => 'some-guid' } }

        context 'and the values are invalid' do
          let(:params) { { guids: false } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:guids]).to include('must be an array')
          end
        end

        it 'sets the message types to the provided values' do
          expect(subject).to be_valid
          expect(subject.guids).to eq(['some-guid'])
        end
      end

      context 'when the service_offering_guids filter is provided' do
        let(:params) { { 'service_offering_guids' => 'some-guid' } }

        context 'and the values are invalid' do
          let(:params) { { service_offering_guids: false } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:service_offering_guids]).to include('must be an array')
          end
        end

        it 'sets the message service_offering_guids to the provided values' do
          expect(subject).to be_valid
          expect(subject.service_offering_guids).to eq(['some-guid'])
        end
      end

      context 'when the service_instance_types filter is provided' do
        let(:params) { { 'service_instance_types' => 'managed_service_instance' } }

        context 'and the values are invalid' do
          let(:params) { { service_instance_types: false } }

          it 'validates and returns an error' do
            expect(subject).not_to be_valid
            expect(subject.errors[:service_instance_types]).to include('must be an array')
          end
        end

        it 'sets the message service_instance_types to the provided values' do
          expect(subject).to be_valid
          expect(subject.service_instance_types).to eq(['managed_service_instance'])
        end
      end
    end
  end
end