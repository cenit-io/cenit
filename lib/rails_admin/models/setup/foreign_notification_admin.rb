module RailsAdmin
  module Models
    module Setup
      module ForeignNotificationAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :label }
            label 'Notification'
            weight 500

            edit do
              field :active, :boolean do
                visible do
                  bindings[:object].data_type ||= bindings[:controller].instance_variable_get(:@data_type_filter)
                  bindings[:object].new_record? == false
                end
              end
              field :data_type do
                required true
                inline_edit false
                read_only do
                  bindings[:object].data_type != nil
                end
                help do
                  text = ''
                  if bindings[:object].data_type.nil?
                    text << 'Required.'
                    text << '<br/>'
                    text << 'To set observers and setting values, you must first use the save and edit action.'
                  end
                  text.html_safe
                end
              end
              field :observers do
                label 'Events'
                inline_add false
                visible { !bindings[:object].data_type.nil? }
                associated_collection_scope do
                  data_type = bindings[:object].data_type || bindings[:controller].object
                  Proc.new { |scope| scope.where(data_type_id: data_type.id) }
                end
                help do
                  text = 'Required.'
                  if bindings[:controller].instance_variable_get(:@model_name) != 'Setup::ForeignNotification'
                    text << '<br/>'
                    text << 'To use a newly created observer in this session or set setting values, you must first use the save and edit action.'
                  end
                  text.html_safe
                end
              end
              field :setting do
                required true
                visible { !bindings[:object].data_type.nil? }
              end
            end

          end
        end

      end
    end
  end
end
