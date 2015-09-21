module Forms
  class GenerateOptions
    include Mongoid::Document

    field :override_data_types, type: Boolean

    rails_admin do
      visible false
      edit do
        field :override_data_types do
          visible do
            bindings[:object].instance_variable_get(:@_to_override).present?
          end
          help nil
        end
      end
    end
  end
end
