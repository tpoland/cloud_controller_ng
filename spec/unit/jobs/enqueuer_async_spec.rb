require 'db_spec_helper'
require 'jobs/enqueuer'
require 'jobs/delete_action_job'
require 'jobs/runtime/model_deletion'
require 'jobs/error_translator_job'

# DelayedJob Plugin Overrides for enforcing callback order and collecting data
class TestDelayedPlugin < Delayed::Plugin
  @@callback_state={}

  def self.get_callback_state
    @@callback_state
  end

  def self.set_callback_state(phase)
    case phase
    when :before_before, :after_before
      callbacks do |lifecycle|
        lifecycle.before(:enqueue) do
          collect_counts(phase)
        end
      end
    when :before_after
      callbacks do |lifecycle|
        lifecycle.after(:enqueue) do
          collect_counts(phase)
        end
      end
    end
  end

  def self.collect_counts (phase)
    @@callback_state[phase]={}
    @@callback_state[phase][:last_pollable_count] = VCAP::CloudController::PollableJobModel.count
    @@callback_state[phase][:delayed_job_count] = Delayed::Job.count
  end
end

class BeforeBeforeEnqueueHook < TestDelayedPlugin
  set_callback_state(:before_before)
end

class AfterBeforeEnqueueHook < TestDelayedPlugin
  set_callback_state(:after_before)
end

class BeforeAfterEnqueueHook < TestDelayedPlugin
  set_callback_state(:before_after)
end

module VCAP::CloudController::Jobs
  RSpec.describe Enqueuer, job_context: :api do
    let(:config_override) do
      {
        jobs: {
          global: {
            timeout_in_seconds: global_timeout,
          }
        }
      }
    end
    let(:global_timeout) { 5.hours }

    before do
      TestConfig.override(config_override)
    end

    shared_examples_for 'a job enqueueing method' do
      let(:job_timeout) { rand(20).hours }
      let(:timeout_calculator) { instance_double(VCAP::CloudController::JobTimeoutCalculator) }

      before do
        expect(VCAP::CloudController::JobTimeoutCalculator).to receive(:new).with(TestConfig.config_instance).and_return(timeout_calculator)
        allow(timeout_calculator).to receive(:calculate).and_return(job_timeout)
      end

      it "populates LoggingContextJob's ID with the one from the thread-local Request" do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |logging_context_job, opts|
          expect(logging_context_job.request_id).to eq request_id
          original_enqueue.call(logging_context_job, opts)
        end

        ::VCAP::Request.current_id = request_id
        Enqueuer.new(wrapped_job, opts).public_send(method_name)
      end

      it 'uses the JobTimeoutCalculator' do
        original_enqueue = Delayed::Job.method(:enqueue)
        expect(Delayed::Job).to receive(:enqueue) do |enqueued_job, opts|
          expect(enqueued_job.handler).to be_a TimeoutJob
          expect(enqueued_job.handler.timeout).to eq(job_timeout)
          original_enqueue.call(enqueued_job, opts)
        end
        Enqueuer.new(wrapped_job, opts).public_send(method_name)
        expect(timeout_calculator).to have_received(:calculate).with(wrapped_job.job_name_in_configuration)
      end
    end

    describe '#enqueue_pollable' do
      let(:wrapped_job) { DeleteActionJob.new(Object, 'guid', double) }
      let(:opts) { { queue: 'my-queue' } }
      let(:request_id) { 'abc123' }
    
      it_behaves_like 'a job enqueueing method' do
        let(:method_name) { 'enqueue_pollable' }
      end

      it 'creates PollableJobModel via callback before enqueing Delayed::Job' do
        dj_plugins = Delayed::Worker.plugins.dup

        Delayed::Worker.plugins.delete(AfterEnqueueHook)
        Delayed::Worker.plugins.delete(BeforeEnqueueHook)
        Delayed::Worker.plugins << BeforeBeforeEnqueueHook  # Collecting state via callback
        Delayed::Worker.plugins << BeforeEnqueueHook
        Delayed::Worker.plugins << AfterBeforeEnqueueHook  # Collecting state via callback
        Delayed::Worker.plugins << BeforeAfterEnqueueHook  # Collecting state via callback
        Delayed::Worker.plugins << AfterEnqueueHook

        Enqueuer.new(wrapped_job, opts).enqueue_pollable
        job_state = TestDelayedPlugin.get_callback_state

        # We are testing an asynchronous event to verify that the PollableJobModel is updated before DelayedJob

                          # We expect that PollableJobs and DelayedJob is empty to start
        expected_state = {:before_before => {:last_pollable_count => 0, :delayed_job_count => 0},
                          # We expect the PollableJobModel to have an entry before DelayedJob
                          :after_before => {:last_pollable_count => 1, :delayed_job_count => 0},
                          # We expect both PollableJobModel and DelayedJob to have a record before the after callback
                          :before_after => {:last_pollable_count => 1, :delayed_job_count => 1}}

        expect(job_state).to eq(expected_state)

        Delayed::Worker.plugins = dj_plugins.dup
      end
    end
  end
end