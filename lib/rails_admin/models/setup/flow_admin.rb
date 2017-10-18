module RailsAdmin
  module Models
    module Setup
      module FlowAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            navigation_icon 'fa fa-cogs'
            weight 500
            object_label_method { :custom_title }
            register_instance_option(:form_synchronized) do
              if bindings[:object].not_shared?
                [
                  :custom_data_type,
                  :data_type_scope,
                  :scope_filter,
                  :scope_evaluator,
                  :lot_size,
                  :connection_role,
                  :webhook,
                  :response_translator,
                  :response_data_type
                ]
              end
            end

            wizard_steps do
              steps =
                {
                  start:
                    {
                      :label => I18n.t('admin.config.flow.wizard.start.label'),
                      :description => I18n.t('admin.config.flow.wizard.start.description')
                    }
                }

              if (translator = bindings[:object].translator)
                unless [::Setup::Updater, ::Setup::Converter].include?(translator.class) || translator.data_type
                  data_type_label =
                    if [::Setup::Renderer, ::Setup::Converter].include?(translator.class)
                      I18n.t('admin.form.flow.source_data_type')
                    else
                      I18n.t('admin.form.flow.target_data_type')
                    end
                  # Adjusting steps for custom_data_type field
                  steps[:data_type] =
                    {
                      :label => "#{I18n.t('admin.config.flow.wizard.source_data_type.label')} #{data_type_label}",
                      :description => "#{I18n.t('admin.config.flow.wizard.source_data_type.description')} #{data_type_label}"
                    }
                end
                if [::Setup::Parser, ::Setup::Renderer].include?(translator.class)
                  steps[:webhook] =
                    {
                      :label => I18n.t('admin.config.flow.wizard.webhook.label'),
                      :description => I18n.t('admin.config.flow.wizard.webhook.description')
                    }
                end
              end
              steps[:end] =
                {
                  label: I18n.t('admin.config.flow.wizard.end.label'),
                  description: I18n.t('admin.config.flow.wizard.end.description')
                } if translator
              steps
            end

            current_step do
              obj = bindings[:object]
              if obj.translator.blank?
                :start
              elsif obj.translator.data_type.blank? && ((p = bindings[:controller].params[abstract_model.param_key]).nil? || p[field(:custom_data_type).foreign_key].nil?)
                :data_type
              elsif wizard_steps.has_key?(:webhook) && obj.webhook.blank?
                :webhook
              else
                :end
              end
            end

            configure :namespace, :enum_edit

            ::Setup::FlowConfig.config_fields.each do |f|
              schema = ::Setup::Flow.data_type.schema['properties'][f]
              if schema['enum']
                type = :enum
              elsif (type = schema['type'].to_sym) == :string
                type = :text
              end
              configure f.to_sym, type
            end

            configure :active, :toggle_boolean

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :description, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :event, :optional_belongs_to do
                inline_edit false
                visible do
                  (f = bindings[:object]).not_shared? || f.data_type_scope.present?
                end
              end
              field :translator do
                inline_edit false
                help I18n.t('admin.form.required')
                shared_read_only
              end
              field :custom_data_type, :optional_belongs_to do
                inline_edit false
                shared_read_only
                visible do
                  f = bindings[:object]
                  if (t = f.translator) && t.data_type.nil?
                    unless f.data_type
                      if f.custom_data_type_selected?
                        f.custom_data_type = nil
                        f.data_type_scope = nil
                      else
                        f.custom_data_type = f.event.try(:data_type)
                      end
                    end
                    true
                  else
                    f.custom_data_type = nil
                    false
                  end
                end
                required do
                  bindings[:object].event.present?
                end
                label do
                  if (translator = bindings[:object].translator)
                    if [:Export, :Conversion].include?(translator.type)
                      I18n.t('admin.form.flow.source_data_type')
                    else
                      I18n.t('admin.form.flow.target_data_type')
                    end
                  else
                    I18n.t('admin.form.flow.data_type')
                  end
                end
              end
              field :data_type_scope do
                shared_read_only
                visible do
                  f = bindings[:object]
                  #For filter scope
                  bindings[:controller].instance_variable_set(:@_data_type, f.data_type)
                  bindings[:controller].instance_variable_set(:@_update_field, 'translator_id')
                  if f.shared?
                    value.present?
                  else
                    f.event &&
                      (t = f.translator) &&
                      t.type != :Import &&
                      (f.custom_data_type_selected? || f.data_type)
                  end
                end
                label do
                  if (translator = bindings[:object].translator)
                    if [:Export, :Conversion].include?(translator.type)
                      I18n.t('admin.form.flow.source_scope')
                    else
                      I18n.t('admin.form.flow.target_scope')
                    end
                  else
                    I18n.t('admin.form.flow.data_type_scope')
                  end
                end
                help I18n.t('admin.form.required')
              end
              field :scope_filter do
                shared_read_only
                visible do
                  f = bindings[:object]
                  f.scope_symbol == :filtered
                end
                partial 'form_triggers'
                help I18n.t('admin.form.required')
              end
              field :scope_evaluator do
                inline_add false
                inline_edit false
                shared_read_only
                visible do
                  f = bindings[:object]
                  f.scope_symbol == :evaluation
                end
                associated_collection_scope do
                  limit = (associated_collection_cache_all ? nil : 30)
                  Proc.new { |scope| scope.where(:parameters.with_size => 1).limit(limit) }
                end
                help I18n.t('admin.form.required')
              end
              field :lot_size do
                shared_read_only
                visible do
                  f = bindings[:object]
                  (t = f.translator) && t.type == :Export &&
                    (f.custom_data_type_selected? || f.data_type) &&
                    (f.event.blank? || f.data_type.blank? || (f.data_type_scope.present? && f.scope_symbol != :event_source))
                end
              end
              field :webhook do
                shared_read_only
                visible do
                  f = bindings[:object]
                  (t = f.translator) && [:Import, :Export].include?(t.type) &&
                    ((f.persisted? || f.custom_data_type_selected? || f.data_type) && (t.type == :Import || f.event.blank? || f.data_type.blank? || f.data_type_scope.present?))
                end
                help I18n.t('admin.form.required')
              end
              field :authorization do
                visible do
                  ((f = bindings[:object]).shared? && f.webhook.present?) ||
                    (t = f.translator) && [:Import, :Export].include?(t.type) &&
                      ((f.persisted? || f.custom_data_type_selected? || f.data_type) && (t.type == :Import || f.event.blank? || f.data_type.blank? || f.data_type_scope.present?))
                end
              end
              field :connection_role do
                visible do
                  ((f = bindings[:object]).shared? && f.webhook.present?) ||
                    (t = f.translator) && [:Import, :Export].include?(t.type) &&
                      ((f.persisted? || f.custom_data_type_selected? || f.data_type) && (t.type == :Import || f.event.blank? || f.data_type.blank? || f.data_type_scope.present?))
                end
              end
              field :before_submit do
                shared_read_only
                visible do
                  f = bindings[:object]
                  (t = f.translator) && [:Import].include?(t.type) &&
                    ((f.persisted? || f.custom_data_type_selected? || f.data_type) && (t.type == :Import || f.event.blank? || f.data_type.blank? || f.data_type_scope.present?))
                end
                associated_collection_scope do
                  limit = (associated_collection_cache_all ? nil : 30)
                  Proc.new { |scope| scope.where('$or': [{ parameters: { '$size': 1 } }, { parameters: { '$size': 2 } }]).limit(limit) }
                end
              end
              field :response_translator do
                shared_read_only
                visible do
                  f = bindings[:object]
                  (t = f.translator) && t.type == :Export &&
                    f.ready_to_save?
                end
                associated_collection_scope do
                  limit = (associated_collection_cache_all ? nil : 30)
                  Proc.new { |scope| scope.where(type: :Import).limit(limit) }
                end
              end
              field :response_data_type do
                inline_edit false
                inline_add false
                shared_read_only
                visible do
                  f = bindings[:object]
                  (resp_t = f.response_translator) &&
                    resp_t.type == :Import &&
                    resp_t.data_type.nil?
                end
                help I18n.t('admin.form.required')
              end
              field :discard_events do
                visible do
                  f = bindings[:object]
                  ((f.translator && f.translator.type == :Import) || f.response_translator.present?) &&
                    f.ready_to_save?
                end
                help I18n.t('admin.form.flow.events_wont_be_fired')
              end
              field :active do
                visible do
                  f = bindings[:object]
                  f.ready_to_save?
                end
              end
              field :auto_retry do
                visible do
                  f = bindings[:object]
                  f.ready_to_save?
                end
              end
              field :notify_request do
                visible do
                  f = bindings[:object]
                  (t = f.translator) &&
                    [:Import, :Export].include?(t.type) &&
                    f.ready_to_save?
                end
                help I18n.t('admin.form.flow.notify_request')
              end
              field :notify_response do
                visible do
                  f = bindings[:object]
                  (t = f.translator) &&
                    [:Import, :Export].include?(t.type) &&
                    f.ready_to_save?
                end
                help help I18n.t('admin.form.flow.notify_response')
              end
              field :after_process_callbacks do
                shared_read_only
                visible do
                  bindings[:object].ready_to_save?
                end
                help I18n.t('admin.form.flow.after_process_callbacks')
                associated_collection_scope do
                  limit = (associated_collection_cache_all ? nil : 30)
                  Proc.new { |scope| scope.where(:parameters.with_size => 1).limit(limit) }
                end
              end
            end

            show do
              field :namespace
              field :name
              field :description
              field :active
              field :event
              field :translator
              field :custom_data_type
              field :data_type_scope
              field :scope_filter
              field :scope_evaluator
              field :lot_size

              field :webhook
              field :authorization
              field :connection_role
              field :before_submit
              field :response_translator
              field :response_data_type

              field :discard_events
              field :notify_request
              field :notify_response
              field :after_process_callbacks

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            list do
              field :namespace
              field :name
              field :active
              field :event
              field :translator
              field :updated_at
            end

            fields :namespace, :name, :description, :active, :event, :translator, :updated_at
          end
        end

      end
    end
  end
end
