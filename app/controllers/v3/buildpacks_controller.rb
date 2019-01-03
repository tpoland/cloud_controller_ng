require 'messages/buildpack_create_message'
require 'messages/buildpacks_list_message'
require 'messages/buildpack_upload_message'
require 'fetchers/buildpack_list_fetcher'
require 'actions/buildpack_create'
require 'actions/buildpack_upload'
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

  def index
    message = BuildpacksListMessage.from_params(query_params)
    invalid_param!(message.errors.full_messages) unless message.valid?

    dataset = BuildpackListFetcher.new.fetch_all(message)

    render status: :ok, json: Presenters::V3::PaginatedListPresenter.new(
      presenter: Presenters::V3::BuildpackPresenter,
      paginated_result: SequelPaginator.new.get_page(dataset, message.try(:pagination_options)),
      path: '/v3/buildpacks',
      message: message
    )
  end

  def upload
    unauthorized! unless permission_queryer.can_write_globally?

    message = BuildpackUploadMessage.create_from_params(hashed_params[:body])
    unprocessable!(message.errors.full_messages) unless message.valid?

    buildpack = Buildpack.find(guid: hashed_params[:guid])
    buildpack_not_found! unless buildpack

    BuildpackUpload.new.upload_async(
        message: message,
        buildpack: buildpack,
        user_audit_info: user_audit_info
    )

    render status: :ok, json: Presenters::V3::BuildpackPresenter.new(buildpack)
  end

  private

  def buildpack_not_found!
    resource_not_found!(:buildpack)
  end
end
