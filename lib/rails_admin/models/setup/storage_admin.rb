module RailsAdmin
  module Models
    module Setup
      module StorageAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Monitors'
            show_in_dashboard false
            weight 620
            visible true
            object_label_method { :label }

            configure :filename do
              label 'File name'
              pretty_value { bindings[:object].storage_name }
            end

            configure :length do
              label 'Size'
              pretty_value do
                if objects = bindings[:controller].instance_variable_get(:@objects)
                  unless max = bindings[:controller].instance_variable_get(:@max_length)
                    bindings[:controller].instance_variable_set(:@max_length, max = objects.collect { |storage| storage.length }.reject(&:nil?).max)
                  end
                  (bindings[:view].render partial: 'size_bar', locals: { max: max, value: bindings[:object].length }).html_safe
                else
                  bindings[:view].number_to_human_size(value)
                end
              end
            end

            configure :storer_model, :model do
              label 'Model'
            end

            configure :storer_object, :record do
              label 'Object'
            end

            configure :storer_property do
              label 'Property'
            end

            configure :metadata, :json_value

            list do
              field :storer_model
              field :storer_object
              field :storer_property
              field :filename
              field :contentType
              field :length
              field :updated_at
            end

            fields :storer_model, :storer_object, :storer_property, :filename, :contentType, :length, :metadata
          end
        end

      end
    end
  end
end
