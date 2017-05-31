module RailsAdmin
  module Config
    module Fields
      module Types
        BelongsToAssociation.class_eval do

          def with(bindings)
            if (obj = bindings[:object]) &&
               obj.new_record? &&
               (controller = bindings[:controller]) &&
               (contextual_params = controller.params[:contextual_params]) &&
               (id = contextual_params[foreign_key])
              obj.send("#{foreign_key}=", id.is_a?(Array) ? id.detect(&:present?) : id)
            end
            super
          end

          register_instance_option :partial do
            associated = bindings[:object].send(association.name)
            if associated &&
               (contextual_params = bindings[:controller].params[:contextual_params]) &&
               (id = contextual_params[foreign_key]) &&
               (id == associated.id.to_s || (id.is_a?(Array) && id.include?(associated.id.to_s)))
              :selected_field
            else
              :form_filtering_select
            end
          end
        end
      end
    end
  end
end
