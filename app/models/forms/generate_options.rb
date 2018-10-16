module Forms
  class GenerateOptions
    include Mongoid::Document

    field :override_data_types, type: Boolean

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :override_data_types do
          visible do
            !Cenit.synchronous_data_type_generation || bindings[:object].instance_variable_get(:@_to_override).present?
          end
          help nil
        end
      end
    end
  end
end
