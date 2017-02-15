module Setup
  class CrossCollectionPullParameter
    include CenitUnscoped
    include HashField
    include RailsAdmin::Models::Setup::CrossCollectionPullParameterAdmin

    build_in_data_type.referenced_by(:location, :property_name)

    field :label, type: String
    hash_field :location
    field :property_name, type: String
    field :description, type: String

    embedded_in :shared_collection, class_name: Setup::CrossSharedCollection.to_s, inverse_of: :pull_parameters

    validates_presence_of :label, :location, :property_name
    validates_length_of :label, maximum: 255

    def process_on(hash_data, options = {})
      options ||= {}
      errors.clear
      if location.is_a?(Hash)
        if location.present?
          obj = hash_data
          location.each do |key, criteria|
            obj = obj && (obj = obj[key]) && ((criteria && Cenit::Utility.find_record(criteria, obj)) || obj)
          end
          if obj
            if property_name.present?
              if (value = options[:value]).nil?
                obj.delete(property_name) unless options[:keep_values]
              else
                obj[property_name] = value
              end
            else
              errors.add(:property_name, "can't be blank")
            end
          else
            errors.add(:location, "can not locate value with #{location.to_json}")
          end
        else
          errors.add(:location, "can't be blank")
        end
      else
        errors.add(:location, 'is not a valid JSON object')
      end
      errors.blank?
    end
  end
end
