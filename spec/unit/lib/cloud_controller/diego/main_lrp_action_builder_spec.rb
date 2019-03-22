require 'spec_helper'

module VCAP::CloudController
  module Diego
    RSpec.describe MainLRPActionBuilder do
      describe '.build' do
        let(:app_model) do
          FactoryBot.create(:app, :buildpack,
          droplet: DropletModel.make(state: 'STAGED'),
          enable_ssh: false
          )
        end

        before do
          TestConfig.override(credhub_api: nil)

          environment = instance_double(Environment)
          allow(Environment).to receive(:new).with(process, {}).and_return(environment)
          allow(environment).to receive(:as_json).and_return(environment_variables)
        end

        let(:ssh_key) { SSHKey.new }
        let(:environment_variables) { ['name' => 'KEY', 'value' => 'running_value'] }
        let(:port_environment_variables) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '4444'),
          ]
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
          enable_ssh:           false,
          )
          process.this.update(updated_at: Time.at(2))
          process.reload
          process.desired_droplet.execution_metadata = execution_metadata
          process
        end

        let(:command) { 'echo "hello"' }
        let(:expected_file_descriptor_limit) { 32 }
        let(:expected_action_environment_variables) do
          [
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'PORT', value: '4444'),
            ::Diego::Bbs::Models::EnvironmentVariable.new(name: 'KEY', value: 'running_value')
          ]
        end
        let(:execution_metadata) { { garbage_fake_metadata_key: 'foo' }.to_json }

        let(:lrp_builder) do
          instance_double(VCAP::CloudController::Diego::Buildpack::DesiredLrpBuilder,
          # cached_dependencies:          expected_cached_dependencies,
          # root_fs:                      'buildpack_root_fs',
          # setup:                        expected_setup_action,
          # global_environment_variables: env_vars,
          # privileged?:                  false,
          ports:                        [4444, 5555],
          port_environment_variables:   port_environment_variables,
          action_user:                  'lrp-action-user',
          # image_layers:                 expected_image_layers,
          start_command:                command,
          )
        end

        let(:expected_app_run_action) {
          ::Diego::Bbs::Models::Action.new(
            run_action: ::Diego::Bbs::Models::RunAction.new(
              path:            '/tmp/lifecycle/launcher',
              args:            ['app', command, execution_metadata],
              log_source:      'APP/PROC/WEB',
              resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
              env:             expected_action_environment_variables,
              user:            'lrp-action-user',
            )
          )
        }

        it 'builds a big codependent action' do
          expect(MainLRPActionBuilder.build(process, lrp_builder, ssh_key)).to eq(
            ::Diego::Bbs::Models::Action.new(
              codependent_action: ::Diego::Bbs::Models::CodependentAction.new(
                actions: [expected_app_run_action]
              )
            )
          )
        end

        it 'without a credhub uri, it not include the VCAP_PLATFORM_OPTIONS' do
          MainLRPActionBuilder.build(process, lrp_builder, ssh_key).codependent_action.actions.
            map { |action| action.run_action.env }.
            each { |env_vars| expect(env_vars).to_not include(an_object_satisfying { |var| var.name == 'VCAP_PLATFORM_OPTIONS' }) }
        end

        context 'when a process has a sidecar' do
          let!(:sidecar) { SidecarModel.make(app: app_model, name: 'my_sidecar', command: 'athenz') }
          let!(:sidecar_process_type) { SidecarProcessTypeModel.make(sidecar: sidecar, type: 'web') }

          it 'includes the sidecar process as a codependent run action' do
            run_actions = MainLRPActionBuilder.build(process, lrp_builder, ssh_key).
                          codependent_action.actions.map(&:run_action)

            # log_source: 'CELL/SSHD',
            expect(run_actions).to include(
              ::Diego::Bbs::Models::RunAction.new(
                user:            'lrp-action-user',
                path:            '/tmp/lifecycle/launcher',
                args:            ['app', 'athenz'],
                resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                env:             expected_action_environment_variables,
              )
            )
          end
        end

        context 'when a process has multiple sidecars' do

        end

        context 'when a process has multiple sidecars' do

        end

        describe 'ssh' do
          before do
            process.app.update(enable_ssh: true)
          end

          it 'includes the ssh daemon process as a codependent run action' do
            actions = MainLRPActionBuilder.build(process, lrp_builder, ssh_key).codependent_action.actions.map(&:run_action)

            expect(actions).to include(
              ::Diego::Bbs::Models::RunAction.new(
                user:            'lrp-action-user',
                path:            '/tmp/lifecycle/diego-sshd',
                args:            [
                  '-address=0.0.0.0:2222',
                  "-hostKey=#{ssh_key.private_key}",
                  "-authorizedKey=#{ssh_key.authorized_key}",
                  '-inheritDaemonEnv',
                  '-logLevel=fatal',
                ],
                resource_limits: ::Diego::Bbs::Models::ResourceLimits.new(nofile: expected_file_descriptor_limit),
                env:             expected_action_environment_variables,
                log_source: 'CELL/SSHD',
              )
            )
          end
        end

        describe 'VCAP_PLATFORM_OPTIONS' do
          context 'when the app has a credhub url' do
            context 'when the interpolation of service bindings is enabled' do
              before do
                TestConfig.override(credential_references: { interpolate_service_bindings: true })
              end

              it 'includes the credhub uri as part of the VCAP_PLATFORM_OPTIONS variable' do
                expected_credhub_url = '{"credhub-uri":"https://credhub.capi.internal:8844"}'
                MainLRPActionBuilder.build(process, lrp_builder, ssh_key).codependent_action.actions.
                  map { |action| action.run_action.env }.
                  each { |env_vars| expect(env_vars).to include(::Diego::Bbs::Models::EnvironmentVariable.new(name: 'VCAP_PLATFORM_OPTIONS', value: expected_credhub_url)) }
              end
            end

            context 'when the interpolation of service bindings is disabled' do
              before do
                TestConfig.override(credential_references: { interpolate_service_bindings: false })
              end

              it 'does not include the VCAP_PLATFORM_OPTIONS' do
                MainLRPActionBuilder.build(process, lrp_builder, ssh_key).codependent_action.actions.
                  map { |action| action.run_action.env }.
                  each { |env_vars| expect(env_vars).to_not include(an_object_satisfying { |var| var.name == 'VCAP_PLATFORM_OPTIONS' }) }
              end
            end
          end
        end
      end
    end
  end
end
