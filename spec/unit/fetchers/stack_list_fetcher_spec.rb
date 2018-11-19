require 'spec_helper'
require 'fetchers/stack_list_fetcher'

module VCAP::CloudController
  RSpec.describe StackListFetcher do
    let!(:fetcher) { StackListFetcher.new }

    describe '#fetch_all' do
      let(:filters) { {} }
      let(:message) { StacksListMessage.from_params(filters) }
      stacks = nil

      before do
        expect(message).to be_valid
        stacks = fetcher.fetch_all(message)
      end

      # TODO: Fix this to work with the preconfigured stacks
      # getting 5 instead of 2 stacks back
      context 'when no filters are specified' do
        VCAP::CloudController::Stack.dataset.destroy
        let!(:stack1) { VCAP::CloudController::Stack.make }
        let!(:stack2) { VCAP::CloudController::Stack.make }
        it 'fetches all the stacks' do
          expect(stacks.count).to eq(2)
          expect(stacks).to match_array([stack1, stack2])
        end
      end
      context 'when the stacks are filtered' do
        VCAP::CloudController::Stack.dataset.destroy
        let!(:stack1) { VCAP::CloudController::Stack.make }
        let!(:stack2) { VCAP::CloudController::Stack.make }
        let(:filters) { { names: [stack1.name] } }

        it 'returns all of the desired stacks' do
          expect(stacks.all).to include(stack1)
          expect(stacks.all).to_not include(stack2)
        end
      end
    end
  end
end

