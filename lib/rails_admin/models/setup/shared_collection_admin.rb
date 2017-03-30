module RailsAdmin
  module Models
    module Setup
      module SharedCollectionAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 020
            label 'Legacy Shared Collection'
            register_instance_option(:discard_submit_buttons) do
              !(a = bindings[:action]) || a.key != :edit
            end
            navigation_label 'Collections'
            object_label_method { :versioned_name }

            visible false

            public_access true
            extra_associations do
              ::Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect do |association|
                association = association.dup
                association[:name] = "data_#{association.name}".to_sym
                RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)
              end
            end

            index_template_name :shared_collection_grid
            index_link_icon 'icon-th-large'

            group :collections
            group :workflows
            group :api_connectors do
              label 'Connectors'
              active true
            end
            group :data
            group :security


            edit do
              field :image do
                visible { !bindings[:object].instance_variable_get(:@sharing) }
              end
              field :logo_background
              field :name do
                required { true }
              end
              field :shared_version do
                required { true }
              end
              field :authors
              field :summary
              field :tags
              field :source_collection do
                visible { !((source_collection = bindings[:object].source_collection) && source_collection.new_record?) }
                inline_edit false
                inline_add false
                associated_collection_scope do
                  source_collection = (obj = bindings[:object]).source_collection
                  Proc.new { |scope|
                    if obj.new_record?
                      scope.where(id: source_collection ? source_collection.id : nil)
                    else
                      scope
                    end
                  }
                end
              end
              field :connections do
                inline_add false
                read_only do
                  !((v = bindings[:object].instance_variable_get(:@_selecting_connections)).nil? || v)
                end
                help do
                  nil
                end
                pretty_value do
                  if bindings[:object].connections.present?
                    v = bindings[:view]
                    ids = ''
                    [value].flatten.select(&:present?).collect do |associated|
                      ids += "<option value=#{associated.id} selected=true/>"
                      amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config
                      am = amc.abstract_model
                      wording = associated.send(amc.object_label_method)
                      can_see = !am.embedded? && (show_action = v.action(:show, am, associated))
                      can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : wording
                    end.to_sentence.html_safe +
                      v.select_tag("#{bindings[:controller].instance_variable_get(:@model_config).abstract_model.param_key}[connection_ids][]", ids.html_safe, multiple: true, style: 'display:none').html_safe
                  else
                    'No connection selected'.html_safe
                  end
                end
                visible do
                  !(obj = bindings[:object]).instance_variable_get(:@_selecting_collection) && obj.source_collection && obj.source_collection.connections.present?
                end
                associated_collection_scope do
                  source_collection = bindings[:object].source_collection
                  connections = (source_collection && source_collection.connections) || []
                  Proc.new { |scope|
                    scope.any_in(id: connections.collect { |connection| connection.id })
                  }
                end
              end
              field :dependencies do
                inline_add false
                read_only do
                  !((v = bindings[:object].instance_variable_get(:@_selecting_dependencies)).nil? || v)
                end
                help do
                  nil
                end
                pretty_value do
                  if bindings[:object].dependencies.present?
                    v = bindings[:view]
                    ids = ''
                    [value].flatten.select(&:present?).collect do |associated|
                      ids += "<option value=#{associated.id} selected=true/>"
                      amc = polymorphic? ? RailsAdmin.config(associated) : associated_model_config
                      am = amc.abstract_model
                      wording = associated.send(amc.object_label_method)
                      can_see = !am.embedded? && (show_action = v.action(:show, am, associated))
                      can_see ? v.link_to(wording, v.url_for(action: show_action.action_name, model_name: am.to_param, id: associated.id), class: 'pjax') : wording
                    end.to_sentence.html_safe +
                      v.select_tag("#{bindings[:controller].instance_variable_get(:@model_config).abstract_model.param_key}[dependency_ids][]", ids.html_safe, multiple: true, style: 'display:none').html_safe
                  else
                    'No dependencies selected'.html_safe
                  end
                end
                visible do
                  !(obj = bindings[:object]).instance_variable_get(:@_selecting_collection)
                end
              end
              field :pull_parameters
              field :pull_count do
                visible { Account.current_super_admin? }
              end
              field :readme do
                visible do
                  !(obj = bindings[:object]).instance_variable_get(:@_selecting_collection) &&
                    !obj.instance_variable_get(:@_selecting_connections)
                end
              end
            end
            show do
              field :image
              field :name do
                pretty_value do
                  bindings[:object].versioned_name
                end
              end
              field :summary do
                pretty_value do
                  value.html_safe
                end
              end
              field :tags
              field :readme, :html_erb
              field :authors
              field :dependencies
              field :pull_count

              field :data_namespaces do
                group :collections
                label 'Namespaces'
                list_fields do
                  %w(name slug)
                end
              end

              field :data_flows do
                group :workflows
                label 'Flows'
                list_fields do
                  %w(namespace name) #TODO Inlude a description field on Flow model
                end
              end

              field :data_translators do
                group :workflows
                label 'Transformations'
                list_fields do
                  %w(namespace name type style)
                end
              end

              field :data_snippets do
                label 'Snippets'
              end

              field :data_events do
                group :workflows
                label 'Events'
                list_fields do
                  %w(namespace name _type)
                end
              end

              field :data_algorithms do
                group :workflows
                label 'Algorithms'
                list_fields do
                  %w(namespace name description)
                end
              end

              field :data_connection_roles do
                group :api_connectors
                label 'Connection roles'
                list_fields do
                  %w(namespace name)
                end
              end

              field :data_webhooks do
                group :api_connectors
                label 'Webhooks'
                list_fields do
                  %w(namespace name path method description)
                end
              end

              field :data_connections do
                group :api_connectors
                label 'Connections'
                list_fields do
                  %w(namespace name url)
                end
              end

              field :data_data_types do
                group :data
                label 'Data types'
                list_fields do
                  %w(title name slug _type)
                end
              end

              field :data_schemas do
                group :data
                label 'Schemas'
                list_fields do
                  %w(namespace uri)
                end
              end

              field :data_custom_validators do
                group :data
                label 'Custom validators'
                list_fields do
                  %w(namespace name _type) #TODO Include a description field for Custom Validator model
                end
              end

              # field :data_data TODO Include collection data field

              field :data_authorizations do
                group :security
                label 'Authorizations'
                list_fields do
                  %w(namespace name _type)
                end
              end

              field :data_oauth_providers do
                group :security
                label 'OAuth providers'
                list_fields do
                  %w(namespace name response_type authorization_endpoint token_endpoint token_method _type)
                end
              end

              field :data_oauth_clients do
                group :security
                label 'OAuth clients'
                list_fields do
                  %w(provider name)
                end
              end

              field :data_oauth2_scopes do
                group :security
                label 'OAuth 2.0 scopes'
                list_fields do
                  %w(provider name description)
                end
              end

              field :_id
              field :updated_at
            end
            list do
              field :image do
                thumb_method :icon
              end
              field :name do
                pretty_value do
                  bindings[:object].versioned_name
                end
              end
              field :authors
              field :summary
              field :tags
              field :pull_count
              field :dependencies
            end
          end
        end

      end
    end
  end
end
