module RailsAdmin
  module Models
    module Setup
      module CollectionFieldsConfigAdmin

        SHARING_INVISIBLE = Proc.new do
          visible { !bindings[:object].instance_variable_get(:@sharing) }
        end

        FIELDS_CONFIG = proc do

          if abstract_model.model == ::Setup::CrossSharedCollection
            configure :readme, :html_erb
            configure :pull_data, :json_value
            configure :swagger_spec, :json_value
          end

          group :compute do
            active false
          end

          configure :translators do
            group :compute
          end

          configure :algorithms do
            group :compute
          end

          configure :applications do
            group :compute
          end

          configure :snippets do
            group :compute
          end

          group :workflows do
            active false
          end

          configure :flows do
            group :workflows
          end

          configure :events do
            group :workflows
          end

          group :api_connectors do
            label 'Connectors'
            active false
          end

          configure :connections do
            group :api_connectors
          end

          configure :resources do
            group :api_connectors
          end

          configure :webhooks do
            group :api_connectors
          end

          configure :connection_roles do
            group :api_connectors
          end

          group :data do
            active false
          end

          configure :data_types do
            group :data
          end

          configure :schemas do
            group :data
          end

          configure :custom_validators do
            group :data
          end

          group :security do
            active false
          end

          configure :authorizations do
            group :security
          end

          configure :oauth_providers do
            group :security
          end

          configure :oauth_clients do
            group :security
          end

          configure :oauth2_scopes do
            group :security
          end

          group :config do
            active false
          end

          configure :namespaces do
            group :config
          end

          group :metadata do
            active false
          end

          configure :metadata, :json_value do
            group :metadata
          end

          groups = {
            data: {
              schemas: 'Schemas',
              custom_validators: 'Validators',
              data_types: 'Data Types'
            },
            api_connectors: {
              connections: 'Connections',
              resources: 'Resources',
              operations: 'Operations',
              webhooks: 'Webhooks',
              connection_roles: 'Connection Roles'
            },
            workflows: {
              flows: 'Flows',
              events: 'Events'
            },
            compute: {
              translators: 'Translators',
              algorithms: 'Algorithms',
              applications: 'Applications',
              snippets: 'Snippets'
            },
            security: {
              authorizations: 'Authorizations',
              oauth_clients: 'OAuth Clients',
              oauth_providers: 'OAuth Providers',
              oauth2_scopes: 'OAuth 2.0 Scopes'
            },
            config: {
              namespaces: 'Namespaces'
            }
          }

          if abstract_model.model == ::Setup::CrossSharedCollection
            groups.each do |group, fields|
              fields.each do |field, label|
                configure :"data_#{field}", :has_many_association do
                  label label
                  group group
                end
              end
            end
          end

          edit do
            field :name
            field :title
            field :image, &SHARING_INVISIBLE

            if abstract_model.model == ::Setup::CrossSharedCollection
              field :shared_version, &SHARING_INVISIBLE
              field :authors, &SHARING_INVISIBLE
              field :summary
              field :categories
            end

            field :tags
            field :readme, :html_erb, &SHARING_INVISIBLE

            if abstract_model.model == ::Setup::CrossSharedCollection
              field :pull_parameters
              field :pull_asynchronous
              field :pull_count do
                visible do
                  User.current.super_admin? &&
                    !(obj = bindings[:object]).instance_variable_get(:@sharing)
                end
              end
            end

            field :flows, &SHARING_INVISIBLE
            field :connection_roles, &SHARING_INVISIBLE
            field :events, &SHARING_INVISIBLE
            field :data_types, &SHARING_INVISIBLE
            field :schemas, &SHARING_INVISIBLE
            field :custom_validators, &SHARING_INVISIBLE
            field :translators, &SHARING_INVISIBLE
            field :algorithms, &SHARING_INVISIBLE
            field :applications, &SHARING_INVISIBLE
            field :snippets, &SHARING_INVISIBLE
            field :webhooks, &SHARING_INVISIBLE
            field :connections, &SHARING_INVISIBLE
            field :resources, &SHARING_INVISIBLE
            field :authorizations, &SHARING_INVISIBLE
            field :oauth_providers, &SHARING_INVISIBLE
            field :oauth_clients, &SHARING_INVISIBLE
            field :oauth2_scopes, &SHARING_INVISIBLE
            field :metadata, :json_value, &SHARING_INVISIBLE
          end

          show do
            field :title
            field :image
            field :name
            field :tags

            prefix =
              if abstract_model.model == ::Setup::CrossSharedCollection
                field :summary do
                  pretty_value do
                    value.html_safe
                  end
                end
                field :readme, :html_erb
                field :categories
                field :authors
                field :pull_count
                'data_'
              else
                field :readme, :html_erb
                ''
              end

            groups.each do |_, fields|
              fields.each do |field, _|
                field "#{prefix}#{field}".to_sym
              end
            end

            field :metadata, :json_value

            field :_id
            field :created_at
            field :updated_at
          end

          unless abstract_model.model == ::Setup::CrossSharedCollection
            list do
              field :title
              field :image do
                thumb_method :icon
              end
              field :name
              field :flows do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :connection_roles do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :translators do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :events do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :data_types do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :schemas do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :custom_validators do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :algorithms do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :applications do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :webhooks do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :connections do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :resources do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :operations do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :authorizations do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :oauth_providers do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :oauth_clients do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :oauth2_scopes do
                pretty_value do
                  value.count > 0 ? value.count : '-'
                end
              end
              field :updated_at
            end
          end
        end
      end
    end
  end
end
