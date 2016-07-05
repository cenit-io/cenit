module Setup
  class CrossCollectionPullParameter
    include CenitUnscoped
    include HashField

    build_in_data_type.referenced_by(:location, :property_name)

    field :label, type: String
    hash_field :location
    field :property_name, type: String

    embedded_in :shared_collection, class_name: Setup::CrossSharedCollection.to_s, inverse_of: :pull_parameters

    validates_presence_of :label, :location, :property_name
    validates_length_of :label, maximum: 255

    def process_on(hash_data, options = {})
      options ||= {}
      errors.clear
      if location.present?
        obj = hash_data
        location.each do |key, criteria|
          obj = obj && (obj = obj[key]) && Cenit::Utility.find_record(criteria, obj)
        end
        if obj
          if property_name.present?
            if (value = options[:value]).nil?
              obj.delete(property_name) unless options[:keep_value]
            else
              obj[property_name] = value
            end
          else
            errors.add(:property_name, "can't be blank")
          end
        else
          errors.add(:base, "can not locate value with #{location.to_json}")
        end
      else
        errors.add(:location, "can't be blank")
      end
      errors.blank?
    end
  end
end
