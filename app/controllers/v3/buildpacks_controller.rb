require 'messages/buildpack_create_message'

class BuildpacksController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = BuildpackCreateMessage.new(hashed_params)
    unprocessable!(message.errors.full_messages) unless message.valid?


    buildpack = Buildpack.create(
      name: message.name,
      stack: message.stack,
      position: message.position,
      enabled: message.enabled,
      locked: message.locked
    )


    render status: :created, json: buildpack.to_json
  rescue Sequel::ValidationFailed => e
    unprocessable!("Stack \"#{message.stack}\" does not exist") if e.message == "stack buildpack_stack_does_not_exist"
    unprocessable!(e)
  end
end
