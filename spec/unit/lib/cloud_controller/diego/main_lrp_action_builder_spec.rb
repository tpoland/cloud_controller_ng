require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe MainLRPActionBuilder do
      describe '.build' do

        let(:app_model) do
          app  = FactoryBot.create(:app, :buildpack,
            droplet: DropletModel.make(state: 'STAGED'),
            enable_ssh: false
          )
        end

        let(:buildpack_lifecycle_data) { app_model.buildpack_lifecycle_data }
        let(:process) do
          process = ProcessModel.make(:process,
                                      app:                  app_model,
                                      state:                'STARTED',
                                      diego:                true,
                                      guid:                 'process-guid',
                                      type:                 'web',
                                      health_check_timeout: 12,
                                      instances:            21,
                                      memory:               128,
                                      disk_quota:           256,
                                      command:              command,
                                      file_descriptors:     32,
                                      health_check_type:    'port',
                                      enable_ssh:           false
          )
          process.this.update(updated_at: Time.at(2))
          process.reload
        end

        let(:command) { 'echo "hello"' }
        let(:expected_file_descriptor_limit) { 32 }
        let(:expected_action_environment_variables) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '4444'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'KEY', value: 'running_value')
          ]
        end
        let(:execution_metadata) { { user: execution_metadata_user }.to_json }
        let(:execution_metadata_user) { nil }

        let(:config) { Config.new({}) }

        let(:lrp_builder) { VCAP::CloudController::Diego::Buildpack::LifecycleProtocol.new.desired_lrp_builder(config, process) }

        it 'builds a big codependent action' do
          expect(MainLRPActionBuilder.build(process, lrp_builder)).to eq(::Diego::Bbs::Models::Action.new(
            codependent_action: ::Diego::Bbs::Models::CodependentAction.new(actions: ::Diego::Bbs::Models::Action.new(
              run_action: ::Diego::Bbs::Models::RunAction.new(
                path:            '/tmp/lifecycle/launcher',
                args:            ['app', command, execution_metadata],
                log_source:      'APP/PROC/WEB',
                resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                env:             expected_action_environment_variables,
                user:            'lrp-action-user',
                )
            ))
          ))
        end
      end
    end

  end
end
