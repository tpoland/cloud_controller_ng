require 'spec_helper'

GLOBAL_SCOPES = %w[
  admin
  admin_read_only
  global_auditor
].freeze

LOCAL_ROLES = %w[
  space_developer
  space_manager
  space_auditor
  org_manager
  org_auditor
  org_billing_manager
].freeze


RSpec.shared_examples 'permissions for list endpoint' do |roles|
  roles.each do |role|
    describe "as an #{role}" do
      it 'returns the correct response status and resources' do
        headers = set_user_with_header_as_role(role: role, org: org, space: space, user: user)
        api_call.call(headers)

        expected_response_code = expected_codes_and_responses[role][:code]
        expect(last_response.status).to eq(expected_response_code), "role #{role}: expected #{expected_response_code}, got: #{last_response.status}"
        if (expected_response_objects = expected_codes_and_responses[role][:response_objects])
          expect(parsed_response['resources']).to include_json(expected_response_objects)
        end
      end
    end
  end
end

RSpec.describe 'Domains Request', type: :request do
  let(:user) { VCAP::CloudController::User.make }
  let(:user_header) { headers_for(user) }
  let(:space) { VCAP::CloudController::Space.make }
  let(:org) { space.organization }

  before do
    VCAP::CloudController::Domain.dataset.destroy # this will clean up the seeded test domains
  end

  describe 'GET /v3/domains' do
    describe 'when the user is not logged in' do
      it 'returns 401 for Unauthenticated requests' do
        get '/v3/domains'
        expect(last_response.status).to eq(401)
      end
    end

    describe 'when the user is logged in' do
      let!(:non_visible_org) { VCAP::CloudController::Organization.make }
      let!(:user_visible_org) { VCAP::CloudController::Organization.make }

      let!(:visible_owned_private_domain) { VCAP::CloudController::PrivateDomain.make(guid: 'domain1', owning_organization: org) } # (d1) - (org) (non_visible_org, user_visible_org)
      let!(:visible_shared_private_domain) { VCAP::CloudController::PrivateDomain.make(guid: 'domain2', owning_organization: non_visible_org) } # (d2) - (non_visible_org) (org)
      let!(:not_visible_private_domain) { VCAP::CloudController::PrivateDomain.make(guid: 'domain3', owning_organization: non_visible_org) } # (d3) - (non_visible_org) ()
      let!(:shared_domain) { VCAP::CloudController::SharedDomain.make(guid: 'domain4') } # (d4) - () ()

      let(:visible_owned_private_domain_object) do
        {
          guid: visible_owned_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: visible_owned_private_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: { guid: org.guid }
            },
            shared_organizations: {
              data: shared_visible_orgs,
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{visible_owned_private_domain.guid}" }
          }
        }
      end

      let(:visible_shared_private_domain_object) do
        {
          guid: visible_shared_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: visible_shared_private_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: { guid: non_visible_org.guid }
            },
            shared_organizations: {
              data: [{ guid: org.guid }]
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{visible_shared_private_domain.guid}" }
          }
        }
      end

      let(:not_visible_private_domain_object) do
        {
          guid: not_visible_private_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: not_visible_private_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: { guid: non_visible_org.guid }
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{not_visible_private_domain.guid}" }
          }
        }
      end

      let(:shared_domain_object) do
        {
          guid: shared_domain.guid,
          created_at: iso8601,
          updated_at: iso8601,
          name: shared_domain.name,
          internal: false,
          relationships: {
            organization: {
              data: nil
            },
            shared_organizations: {
              data: []
            }
          },
          links: {
            self: { href: "#{link_prefix}/v3/domains/#{shared_domain.guid}" }
          }
        }
      end

      before do
        non_visible_org.add_private_domain(visible_owned_private_domain)
        org.add_private_domain(visible_shared_private_domain)
        user_visible_org.add_private_domain(visible_owned_private_domain)
      end

      describe 'required scopes' do
        let (:shared_visible_orgs) { [{ guid: non_visible_org.guid }, { guid: user_visible_org.guid }] }

        context 'when the user does not have the required scopes' do
          let(:user_header) { headers_for(user, scopes: []) }

          it 'returns a 403' do
            get '/v3/domains', nil, user_header
            expect(last_response.status).to eq(403)
          end
        end

        context 'when the user has the required scopes' do
          let(:api_call) { lambda { |user_headers| get '/v3/domains', nil, user_headers } }
          let(:expected_codes_and_responses) do
            {
              'admin' => {
                code: 200,
                response_objects: [
                  visible_owned_private_domain_object,
                  visible_shared_private_domain_object,
                  not_visible_private_domain_object,
                  shared_domain_object
                ]
              },
              'admin_read_only' => {
                code: 200,
                response_objects: [
                  visible_owned_private_domain_object,
                  visible_shared_private_domain_object,
                  not_visible_private_domain_object,
                  shared_domain_object
                ]
              },
              'global_auditor' => {
                code: 200,
                response_objects: [
                  visible_owned_private_domain_object,
                  visible_shared_private_domain_object,
                  not_visible_private_domain_object,
                  shared_domain_object
                ]
              },
            }.freeze
          end

          it_behaves_like 'permissions for list endpoint', GLOBAL_SCOPES
        end
      end

      ## need to give the user roles in the user_visible_org as well?
      # can see d1 d2 d4 except billing manager who can only see d4
      # just need to expected_response.merge({resources=>response_objects})
      describe 'org/space roles' do
        before do
          user_visible_org.add_manager(user)
        end

        let (:shared_visible_orgs) { [{ guid: user_visible_org.guid }] }

        let(:api_call) { lambda { |user_headers| get '/v3/domains', nil, user_headers } }

        # Is there a better way to word this context?
        # Also note, RSpec output will not display these context descriptions due to use of it_behaves_like.
        context 'when user can read private domains in their orgs' do
          let(:expected_codes_and_responses) do
            (LOCAL_ROLES - ['org_billing_manager']).each_with_object({}) do |local_role, expected|
              expected[local_role] = {
                code: 200,
                response_objects: [
                  visible_owned_private_domain_object,
                  visible_shared_private_domain_object,
                  shared_domain_object,
                ]
              }
            end.freeze
          end

          it_behaves_like 'permissions for list endpoint', LOCAL_ROLES - ['org_billing_manager']
        end

        # Is there a better way to word this context?
        # Also note, RSpec output will not display these context descriptions due to use of it_behaves_like.
        context 'when user cannot read private domains in one of their orgs' do
          let(:expected_codes_and_responses) do
            {
              'org_billing_manager' => {
                code: 200,
                response_objects: [
                  visible_owned_private_domain_object,
                  shared_domain_object
                ]
              }
            }.freeze
          end

          # How do we capture the idea that this user has roles:
          # in `org`: org_billing_manager
          # in `user_visible_org`: in org_manager
          it_behaves_like 'permissions for list endpoint', ['org_billing_manager']
        end

      end


      context 'for the future' do
        let!(:shared_domain) { VCAP::CloudController::SharedDomain.make(name: 'my-domain.edu', guid: 'shared_domain') }
        let!(:private_domain) { VCAP::CloudController::PrivateDomain.make(name: 'my-private-domain.edu', owning_organization: org, guid: 'private_domain') }

        let(:org2) { VCAP::CloudController::Organization.make }
        let(:org3) { VCAP::CloudController::Organization.make }

        before do
          set_current_user_as_role(org: org2, user: user, role: 'org_manager')
          org2.add_private_domain(private_domain)
          org3.add_private_domain(private_domain)
        end

        it 'lists all domains with filtered shared_orgs' do
          get '/v3/domains', nil, user_headers

          expect(last_response.status).to eq(200)

          parsed_response = MultiJson.load(last_response.body)
          expect(parsed_response).to be_a_response_like(
            {
              'pagination' => {
                'total_results' => 2,
                'total_pages' => 1,
                'first' => {
                  'href' => "#{link_prefix}/v3/domains?page=1&per_page=50"
                },
                'last' => {
                  'href' => "#{link_prefix}/v3/domains?page=1&per_page=50"
                },
                'next' => nil,
                'previous' => nil
              },
              'resources' => [
                {
                  'guid' => 'shared_domain',
                  'created_at' => iso8601,
                  'updated_at' => iso8601,
                  'name' => 'my-domain.edu',
                  'internal' => false,
                  'relationships' => {
                    'organization' => {
                      'data' => nil
                    },
                    'shared_organizations' => {
                      'data' => []
                    }
                  },
                  'links' => {
                    'self' => { 'href' => "#{link_prefix}/v3/domains/shared_domain" }
                  }
                },
                {
                  'guid' => 'private_domain',
                  'created_at' => iso8601,
                  'updated_at' => iso8601,
                  'name' => 'my-private-domain.edu',
                  'internal' => false,
                  'relationships' => {
                    'organization' => {
                      'data' => {
                        'guid' => org.guid
                      }
                    },
                    'shared_organizations' => {
                      'data' => [{ 'guid' => org2.guid }]
                    }
                  },
                  'links' => {
                    'self' => { 'href' => "#{link_prefix}/v3/domains/private_domain" }
                  }
                }
              ]
            }
          )
        end
      end
    end

    describe 'POST /v3/domains' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      context 'when not authenticated' do
        it 'returns 401' do
          params = {}
          headers = {}

          post '/v3/domains', params, headers

          expect(last_response.status).to eq(401)
        end
      end

      context 'when authenticated but not admin' do
        let(:params) do
          {
            name: 'my-domain.biz',
            relationships: {
              organization: {
                data: {
                  guid: org.guid
                }
              }
            },
          }
        end

        context 'when org manager' do
          before do
            set_current_user_as_role(role: 'org_manager', org: org, user: user)
          end

          let(:headers) { headers_for(user) }

          context 'when the feature flag is enabled' do
            it 'returns a 201 and creates a private domain' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(201)

              domain = VCAP::CloudController::PrivateDomain.last

              expected_response = {
                'name' => params[:name],
                'internal' => false,
                'guid' => domain.guid,
                'relationships' => {
                  'organization' => {
                    'data' => {
                      'guid' => org.guid
                    }
                  },
                  'shared_organizations' => {
                    'data' => []
                  }
                },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/domains/#{domain.guid}"
                  }
                }
              }
              expect(parsed_response).to be_a_response_like(expected_response)
            end
          end

          context 'when the org is suspended' do
            before do
              org.status = 'suspended'
              org.save
            end
            it 'returns a 403' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(403)
            end
          end

          context 'when the feature flag is disabled' do
            let!(:feature_flag) { VCAP::CloudController::FeatureFlag.make(name: 'private_domain_creation', enabled: false) }
            it 'returns a 403' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(403)
            end
          end
        end

        context 'when not an org manager' do
          let(:user) { VCAP::CloudController::User.make }
          let(:headers) { headers_for(user) }

          it 'returns 403' do
            post '/v3/domains', params.to_json, headers

            expect(last_response.status).to eq(403)
          end
        end
      end

      context 'when authenticated and admin' do
        let(:user) { VCAP::CloudController::User.make }
        let(:headers) { admin_headers_for(user) }
        context 'when creating a shared domain' do
          context 'when provided valid arguments' do
            let(:params) do
              {
                name: 'my-domain.biz',
                internal: true,
              }
            end

            it 'returns 201' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(201)

              domain = VCAP::CloudController::Domain.last

              expected_response = {
                'name' => params[:name],
                'internal' => params[:internal],
                'guid' => domain.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'relationships' => {
                  'organization' => {
                    'data' => nil
                  },
                  'shared_organizations' => {
                    'data' => [],
                  }
                },
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/domains/#{domain.guid}"
                  }
                }
              }
              expect(parsed_response).to be_a_response_like(expected_response)
            end
          end

          context 'when provided invalid arguments' do
            let(:params) do
              {
                name: "#{'f' * 63}$"
              }
            end

            it 'returns 422' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expected_err = ['Name does not comply with RFC 1035 standards',
                'Name must contain at least one "."',
                'Name subdomains must each be at most 63 characters',
                'Name must consist of alphanumeric characters and hyphens']
              expect(parsed_response['errors'][0]['detail']).to eq expected_err.join(', ')
            end
          end
        end

        context 'when creating a private domain' do
          context 'when params are valid' do
            let(:params) do
              {
                name: 'my-domain.biz',
                relationships: {
                  organization: {
                    data: {
                      guid: org.guid
                    }
                  }
                },
              }
            end

            it 'returns a 201 and creates a private domain' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(201)

              domain = VCAP::CloudController::PrivateDomain.last

              expected_response = {
                'name' => params[:name],
                'internal' => false,
                'guid' => domain.guid,
                'relationships' => {
                  'organization' => {
                    'data' => {
                      'guid' => org.guid
                    }
                  },
                  'shared_organizations' => {
                    'data' => [],
                  }
                },
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'links' => {
                  'self' => {
                    'href' => "#{link_prefix}/v3/domains/#{domain.guid}"
                  }
                }
              }
              expect(parsed_response).to be_a_response_like(expected_response)
            end
          end

          context 'when the params are invalid' do
            context 'creating a sub domain of a domain scoped to another organization' do
              let(:organization_to_scope_to) { VCAP::CloudController::Organization.make }
              let(:existing_scoped_domain) { VCAP::CloudController::PrivateDomain.make }

              let(:params) do
                {
                  name: "foo.#{existing_scoped_domain.name}",
                  relationships: {
                    organization: {
                      data: {
                        guid: organization_to_scope_to.guid
                      }
                    }
                  }
                }
              end

              it 'returns a 422 and an error' do
                post '/v3/domains', params.to_json, headers

                expect(last_response.status).to eq(422)

                expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{params[:name]}\""\
" cannot be created because \"#{existing_scoped_domain.name}\" is already reserved by another domain"
              end
            end

            context 'when the org doesnt exist' do
              let(:params) do
                {
                  name: 'my-domain.biz',
                  relationships: {
                    organization: {
                      data: {
                        guid: 'non-existent-guid'
                      }
                    }
                  }
                }
              end

              it 'returns a 422 and a helpful error message' do
                post '/v3/domains', params.to_json, headers

                expect(last_response.status).to eq(422)

                expect(parsed_response['errors'][0]['detail']).to eq 'Organization with guid \'non-existent-guid\' does not exist or you do not have access to it.'
              end
            end

            context 'when the org has exceeded its private domains quota' do
              let(:params) do
                {
                  name: 'my-domain.biz',
                  relationships: {
                    organization: {
                      data: {
                        guid: org.guid
                      }
                    }
                  }
                }
              end
              it 'returns a 422 and a helpful error message' do
                org.update(quota_definition: VCAP::CloudController::QuotaDefinition.make(total_private_domains: 0))

                post '/v3/domains', params.to_json, headers

                expect(last_response.status).to eq(422)

                expect(parsed_response['errors'][0]['detail']).to eq "The number of private domains exceeds the quota for organization \"#{org.name}\""
              end
            end
          end

          context 'when the domain is in the list of reserved private domains' do
            let(:params) do
              {
                name: 'com.ac',
                relationships: {
                  organization: {
                    data: {
                      guid: org.guid
                    }
                  }
                }
              }
            end

            before(:each) do
              TestConfig.override({ reserved_private_domains: File.join(Paths::FIXTURES, 'config/reserved_private_domains.dat') })
            end

            it 'returns a 422 with a error message about reserved domains' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expect(parsed_response['errors'][0]['detail']).to eq 'The "com.ac" domain is reserved and cannot be used for org-scoped domains.'
            end
          end
        end

        describe 'collisions' do
          context 'with an existing domain' do
            let!(:existing_domain) { VCAP::CloudController::SharedDomain.make }

            let(:params) do
              {
                name: existing_domain.name,
              }
            end

            it 'returns 422' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expect(parsed_response['errors'][0]['detail']).to eq "The domain name \"#{existing_domain.name}\" is already in use"
            end
          end

          context 'with an existing route' do
            let(:existing_domain) { VCAP::CloudController::SharedDomain.make }
            let(:existing_route) { VCAP::CloudController::Route.make(domain: existing_domain) }
            let(:domain_name) { existing_route.fqdn }

            let(:params) do
              {
                name: domain_name,
              }
            end

            it 'returns 422' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expect(parsed_response['errors'][0]['detail']).to match(
                /The domain name "#{domain_name}" cannot be created because "#{existing_route.fqdn}" is already reserved by a route/
              )
            end
          end

          context 'with an existing route as a subdomain' do
            let(:existing_route) { VCAP::CloudController::Route.make }
            let(:domain) { "sub.#{existing_route.fqdn}" }

            let(:params) do
              {
                name: domain,
              }
            end

            it 'returns 422' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expect(parsed_response['errors'][0]['detail']).to match(
                /The domain name "#{domain}" cannot be created because "#{existing_route.fqdn}" is already reserved by a route/
              )
            end
          end

          context 'with an existing unscoped domain as a subdomain' do
            let(:existing_domain) { VCAP::CloudController::SharedDomain.make }
            let(:domain) { "sub.#{existing_domain.name}" }

            let(:params) do
              {
                name: domain,
              }
            end

            it 'returns 201' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(201)

              expect(parsed_response['name']).to eq domain
            end
          end

          context 'with an existing scoped domain as a subdomain' do
            let(:existing_domain) { VCAP::CloudController::PrivateDomain.make }
            let(:domain) { "sub.#{existing_domain.name}" }

            let(:params) do
              {
                name: domain,
              }
            end

            it 'returns 422' do
              post '/v3/domains', params.to_json, headers

              expect(last_response.status).to eq(422)

              expect(parsed_response['errors'][0]['detail']).to eq(
                %{The domain name "#{domain}" cannot be created because "#{existing_domain.name}" is already reserved by another domain}
              )
            end
          end
        end
      end
    end

    describe 'GET /v3/domains/:guid' do
      before do
        org.add_user(user)
        space.add_developer(user)
      end

      context 'when authenticated' do
        context 'when the domain is shared and exists' do
          let(:shared_domain) { VCAP::CloudController::SharedDomain.make }

          it 'returns 200 and the domain' do
            params = {}
            get "/v3/domains/#{shared_domain.guid}", params, user_header

            expect(last_response.status).to eq(200)
            expect(parsed_response).to be_a_response_like(
              {
                'guid' => shared_domain.guid,
                'created_at' => iso8601,
                'updated_at' => iso8601,
                'name' => shared_domain.name,
                'internal' => shared_domain.internal,
                'relationships' => {
                  'organization' => {
                    'data' => nil },
                  'shared_organizations' => {
                    'data' => [] } },
                'links' => {
                  'self' => { 'href' => "#{link_prefix}/v3/domains/#{shared_domain.guid}" }
                }
              }
            )
          end
        end

        context 'when the domain is private' do
          context 'domain scoped to an org the user can read' do
            let(:private_domain) { VCAP::CloudController::PrivateDomain.make(owning_organization: org) }

            context 'domain not shared with any other org' do
              it 'returns 200 and the domain without any shared orgs' do
                params = {}
                get "/v3/domains/#{private_domain.guid}", params, user_header

                expect(last_response.status).to eq(200)
                expect(parsed_response).to be_a_response_like(
                  {
                    'guid' => private_domain.guid,
                    'created_at' => iso8601,
                    'updated_at' => iso8601,
                    'name' => private_domain.name,
                    'internal' => private_domain.internal,
                    'relationships' => {
                      'organization' => {
                        'data' => { 'guid' => org.guid.to_s } },
                      'shared_organizations' => { 'data' => [] } },
                    'links' => {
                      'self' => { 'href' => "#{link_prefix}/v3/domains/#{private_domain.guid}" }
                    }
                  }
                )
              end
            end

            context 'domain shared with org that user has read permissions for' do
              let(:org2) { VCAP::CloudController::Organization.make }

              before do
                set_current_user_as_role(org: org2, user: user, role: 'org_manager')
                org2.add_private_domain(private_domain)
              end

              it 'returns 200 and the domain with the shared org' do
                params = {}
                get "/v3/domains/#{private_domain.guid}", params, user_header

                expect(last_response.status).to eq(200)
                expect(parsed_response).to be_a_response_like(
                  {
                    'guid' => private_domain.guid,
                    'created_at' => iso8601,
                    'updated_at' => iso8601,
                    'name' => private_domain.name,
                    'internal' => private_domain.internal,
                    'relationships' => {
                      'organization' => {
                        'data' => { 'guid' => org.guid } },
                      'shared_organizations' => { 'data' => [
                        { 'guid' => org2.guid }
                      ] } },
                    'links' => {
                      'self' => { 'href' => "#{link_prefix}/v3/domains/#{private_domain.guid}" }
                    }
                  }
                )
              end
            end

            context 'domain shared with org that user does not have read permissions for' do
              let(:org2) { VCAP::CloudController::Organization.make }

              before do
                org2.add_private_domain(private_domain)
              end

              it 'returns 200 and the domain without any shared orgs' do
                params = {}
                get "/v3/domains/#{private_domain.guid}", params, user_header

                expect(last_response.status).to eq(200)
                expect(parsed_response).to be_a_response_like(
                  {
                    'guid' => private_domain.guid,
                    'created_at' => iso8601,
                    'updated_at' => iso8601,
                    'name' => private_domain.name,
                    'internal' => private_domain.internal,
                    'relationships' => {
                      'organization' => {
                        'data' => { 'guid' => org.guid } },
                      'shared_organizations' => { 'data' => [] } },
                    'links' => {
                      'self' => { 'href' => "#{link_prefix}/v3/domains/#{private_domain.guid}" }
                    }
                  }
                )
              end
            end
          end
        end
      end
    end
  end
end
