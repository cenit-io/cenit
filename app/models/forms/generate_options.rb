module Forms
  class GenerateOptions
    include Mongoid::Document

    field :override_data_types, type: Boolean

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      register_instance_option(:after_form_partials) do
        %w(shutdown_and_reload)
      end
      edit do
        field :override_data_types do
          visible do
            Cenit.asynchronous_data_type_generation || bindings[:object].instance_variable_get(:@_to_override).present?
          end
          help nil
        end
      end
    end
  end
end
