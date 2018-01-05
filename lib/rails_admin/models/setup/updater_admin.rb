module RailsAdmin
  module Models
    module Setup
      module UpdaterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 414
            configure :code, :code
            navigation_label 'Transforms'
            navigation_icon 'fa fa-refresh'

            wizard_steps do
              steps =
                {
                  start:
                    {
                      :label => I18n.t('admin.config.updater.wizard.start.label'),
                      :description => I18n.t('admin.config.updater.wizard.start.description')
                    },
                  end:
                    {
                      label: I18n.t('admin.config.updater.wizard.end.label'),
                      description: I18n.t('admin.config.updater.wizard.end.description')
                    }
                }
            end

            current_step do
              obj = bindings[:object]
              if obj.style.blank?
                :start
              else
                :end
              end
            end

            configure :namespace, :enum_edit

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY
              field :name, &RailsAdmin::Config::Fields::Base::SHARED_READ_ONLY

              field :target_data_type do
                shared_read_only
                inline_edit false
                inline_add false
                help 'Optional'
              end

              field :discard_events do
                shared_read_only
                help "Events won't be fired for created or updated records if checked"
              end

              field :style do
                shared_read_only
                visible { bindings[:object].type.present? }
                help 'Required'
              end

              field :source_handler do
                shared_read_only
                visible { (t = bindings[:object]).style.present? }
                help { 'Handle sources on code' }
              end

              field :code, :code do
                visible { bindings[:object].style.present? && bindings[:object].style != 'chain' }
                help { 'Required' }
                code_config do
                  {
                    mode: case bindings[:object].style
                          when 'html.erb'
                            'text/html'
                          when 'xslt'
                            'application/xml'
                          else
                            'text/x-ruby'
                          end
                  }
                end
              end
            end

            show do
              field :namespace
              field :name
              field :target_data_type
              field :discard_events
              field :style
              field :source_handler
              field :code

              field :_id
              field :created_at
              #field :creator
              field :updated_at
              #field :updater
            end

            list do
              field :namespace
              field :name
              field :target_data_type
              field :style
              field :updated_at
            end

            filter_query_fields :namespace, :name
          end

        end

      end
    end
  end
end
