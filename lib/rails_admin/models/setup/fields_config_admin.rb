module RailsAdmin
  module Models
    module Setup
      module FieldsConfigAdmin

        def self.shared_read_only
          Proc.new do
            instance_eval do
              read_only { (obj = bindings[:object]).creator_id != User.current.id && obj.shared? }
            end
          end
        end

        def self.shared_non_editable
          Proc.new do
            instance_eval do
              RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_read_only
            end
          end
        end

        def self.collection_fields_config
          Proc.new do

            if abstract_model.model == ::Setup::CrossSharedCollection
              configure :readme, :html_erb
              configure :pull_data, :json_value
              configure :data, :json_value
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

            configure :data do
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

            edit do
              field :name
              field :title
              field :image, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible

              if abstract_model.model == ::Setup::CrossSharedCollection
                field :shared_version, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
                field :authors, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
                field :summary
                field :categories
              end

              field :tags
              field :readme, :html_erb, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible

              if abstract_model.model == ::Setup::CrossSharedCollection
                field :pull_parameters
                field :pull_count do
                  visible do
                    User.current.super_admin? &&
                      !(obj = bindings[:object]).instance_variable_get(:@sharing)
                  end
                end
              end

              field :flows, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :connection_roles, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :events, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :data_types, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :schemas, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :custom_validators, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :translators, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :algorithms, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :applications, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :snippets, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :webhooks, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :connections, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :resources, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :authorizations, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :oauth_providers, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :oauth_clients, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :oauth2_scopes, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :data, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
              field :metadata, &RailsAdmin::Models::Setup::FieldsConfigAdmin.sharing_collection_invisible
            end

            show do
              field :title
              field :image
              field :name
              field :tags

              prefix =
                if abstract_model.model == ::Setup::CrossSharedCollection
                  field :summary
                  field :categories
                  field :authors
                  field :pull_count
                  'data_'
                else
                  ''
                end

              field :readme, :html_erb

              instance_eval do
                field "#{prefix}schemas".to_sym do
                  label 'Schemas'
                  group :data
                end
                field "#{prefix}custom_validators".to_sym do
                  label 'Validators'
                  group :data
                end
                field "#{prefix}data_types".to_sym do
                  label 'Data Types'
                  group :data
                end

                field "#{prefix}connections".to_sym do
                  label 'Connections'
                  group :api_connectors
                end

                field "#{prefix}resources".to_sym do
                  label 'Resources'
                  group :api_connectors
                end

                field "#{prefix}operations".to_sym do
                  label 'Operations'
                  group :api_connectors
                end

                field "#{prefix}webhooks".to_sym do
                  label 'Webhooks'
                  group :api_connectors
                end

                field "#{prefix}connection_roles".to_sym do
                  label 'Connection Roles'
                  group :api_connectors
                end

                field "#{prefix}flows".to_sym do
                  label 'Flows'
                  group :workflows
                end

                field "#{prefix}events".to_sym do
                  label 'Events'
                  group :workflows
                end

                field "#{prefix}translators".to_sym do
                  label 'Translators'
                  group :compute
                end

                field "#{prefix}algorithms".to_sym do
                  label 'Algorithms'
                  group :compute
                end

                field "#{prefix}applications".to_sym do
                  label 'Applications'
                  group :compute
                end

                field "#{prefix}snippets".to_sym do
                  label 'Snippets'
                  group :compute
                end

                field "#{prefix}authorizations".to_sym do
                  label 'Authorizations'
                  group :security
                end

                field "#{prefix}oauth_clients".to_sym do
                  label 'OAuth Clients'
                  group :security
                end

                field "#{prefix}oauth_providers".to_sym do
                  label 'OAuth Providers'
                  group :security
                end

                field "#{prefix}oauth2_scopes".to_sym do
                  label 'OAuth 2.0 Scopes'
                  group :security
                end

                field "#{prefix}namespaces".to_sym do
                  label 'Namespaces'
                  group :config
                end

                field :metadata
              end

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
                field :data
                field :updated_at
              end
            end
          end
        end

        def self.sharing_collection_invisible
          Proc.new do
            instance_eval do
              visible { !(obj = bindings[:object]).instance_variable_get(:@sharing) }
            end
          end
        end

      end
    end
  end
end
