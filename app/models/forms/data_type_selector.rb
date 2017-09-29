module Forms
  class DataTypeSelector
    include Mongoid::Document
    include Setup::HashField
    include AccountScoped

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    hash_field :scope

    validate do
      errors.add(:data_type, "can't be blank") if data_type.blank?
      errors.present?
    end

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :data_type do
          help 'Required'
          inline_edit false
          inline_add false
          associated_collection_scope do
            data_type_scope = bindings[:object].scope
            limit = (associated_collection_cache_all ? nil : 30)
            Proc.new { |scope| scope.merge(Setup::DataType.where(data_type_scope)).limit(limit) }
          end
        end
      end
    end
  end
end
