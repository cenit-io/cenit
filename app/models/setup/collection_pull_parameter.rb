module Setup
  class CollectionPullParameter
    include ReqRejValidator
    include CenitUnscoped
    include HashField

    build_in_data_type.referenced_by(:type, :name, :property, :key)

    field :label, type: String
    hash_field :location
    field :property_name, type: String


    field :type, type: Symbol
    field :name, type: String
    field :property, type: String
    field :key, type: Symbol
    field :parameter, type: String

    embedded_in :shared_collection, class_name: Setup::SharedCollection.to_s, inverse_of: :pull_parameters

    def relocate
      location.empty? &&
        begin
          h = {}
          t = type.to_s.downcase.pluralize
          if (objs = _parent.data[t]) || (objs = _parent.dependencies_data[t])
            obj = objs.detect { |v| v['name'] == name.to_s }
            Setup::Collection.reflect_on_association(t).klass.data_type.get_referenced_by.each do |primary_field|
              h[primary_field.to_s] = obj[primary_field.to_s]
            end
            h.delete_if { |_, v| v.nil? }
            h = { t => h }
            if key.present?
              h[property] = { 'key' => key.to_s }
              self.property_name = 'value'
            else
              self.property_name = property.to_s
            end
            self.location = h
            true
          else
            false
          end
        end
    end

    validates_presence_of :label, :location, :property_name
    validates_length_of :label, maximum: 255
    validates_uniqueness_of :parameter

    def process_on(hash_data, options)
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
