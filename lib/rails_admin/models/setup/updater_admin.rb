module RailsAdmin
  module Models
    module Setup
      module UpdaterAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            weight 414
            configure :code, :code
            navigation_label 'Transformations'

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

            edit do
              field :namespace, :enum_edit, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable
              field :name, &RailsAdmin::Models::Setup::FieldsConfigAdmin.shared_non_editable

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
              field :code do
                pretty_value do
                  "<pre><code class='ruby'>#{value}</code></pre>".html_safe
                end
              end

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
          end

          config.model ::Setup::AlgorithmOutput do
            navigation_label 'Compute'
            weight -405
            visible false

            configure :records_count
            configure :input_parameters
            configure :created_at do
              label 'Recorded at'
            end

            extra_associations do
              association = Mongoid::Relations::Metadata.new(
                name: :records, relation: Mongoid::Relations::Referenced::Many,
                inverse_class_name: ::Setup::AlgorithmOutput.to_s, class_name: ::Setup::AlgorithmOutput.to_s
              )
              [RailsAdmin::Adapters::Mongoid::Association.new(association, abstract_model.model)]
            end

            show do
              field :created_at
              field :input_parameters
              field :records_count
            end

            fields :created_at, :input_parameters, :records_count
          end
        end

      end
    end
  end
end
