require 'presenters/v3/base_presenter'
require 'presenters/mixins/metadata_presentation_helpers'

module VCAP::CloudController::Presenters::V3
  class BuildpackPresenter < BasePresenter
    include VCAP::CloudController::Presenters::Mixins::MetadataPresentationHelpers

    def initialize(can_upload_buildpack, *args)
      @display_bits_service_url = can_upload_buildpack
      super(*args)
    end

    def to_hash
      {
        guid: buildpack.guid,
        created_at: buildpack.created_at,
        updated_at: buildpack.updated_at,
        name: buildpack.name,
        stack: buildpack.stack,
        state: buildpack.state,
        filename: buildpack.filename,
        position: buildpack.position,
        enabled: buildpack.enabled,
        locked: buildpack.locked,
        metadata: {
          labels: hashified_labels(buildpack.labels),
          annotations: hashified_annotations(buildpack.annotations),
        },
        links: build_links,
      }
    end

    private

    def buildpack
      @resource
    end

    def build_links
      url_builder = VCAP::CloudController::Presenters::ApiUrlBuilder.new

      {
        self: {
          href: url_builder.build_url(path: "/v3/buildpacks/#{buildpack.guid}")
        },
        upload: get_upload_url(url_builder)
      }
    end

    def get_upload_url(url_builder)
      if VCAP::CloudController::Config.config.get(:bits_service, :enabled)
        bits_service_upload_link
      else
        {
          href: url_builder.build_url(path: "/v3/buildpacks/#{buildpack.guid}/upload"),
          method: 'POST'
        }
      end
    end

    def bits_service_upload_link
      return nil unless @display_bits_service_url

      {href: bits_service_client.blob('').public_upload_url, method: 'POST'}
    end

    def bits_service_client
      CloudController::DependencyLocator.instance.buildpack_blobstore
    end
  end
end
