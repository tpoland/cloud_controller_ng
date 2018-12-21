require 'messages/buildpack_create_message'
require 'actions/buildpack_create'
require 'presenters/v3/buildpack_presenter'

class BuildpacksController < ApplicationController
  def create
    unauthorized! unless permission_queryer.can_write_globally?

    message = BuildpackCreateMessage.new(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    buildpack = BuildpackCreate.new.create(message)

    render status: :created, json: Presenters::V3::BuildpackPresenter.new(buildpack)
  rescue BuildpackCreate::Error => e
    unprocessable!(e)
  end

  def show
    buildpack = Buildpack.find(guid: hashed_params[:guid])
    buildpack_not_found! unless buildpack

    render status: :ok, json: Presenters::V3::BuildpackPresenter.new(buildpack)
  end

  def upload
    unauthorized! unless permission_queryer.can_write_globally?

    uploaded_file = CloudController::DependencyLocator.instance.upload_handler.uploaded_file(request.POST, 'buildpack')
    uploaded_filename = CloudController::DependencyLocator.instance.upload_handler.uploaded_filename(request.POST, 'buildpack')

    uploaded_filename = File.basename(uploaded_filename)

    render status: :ok, json: {}
  end


  private

  def buildpack_not_found!
    resource_not_found!(:buildpack)
  end
end
