module Setup
  class CrossCollectionPullParameter
    include CenitUnscoped
    include HashField
    include ::RailsAdmin::Models::Setup::CrossCollectionPullParameterAdmin

    build_in_data_type.referenced_by(:label)

    field :_id, type: String, default: lambda { "oid_#{BSON::ObjectId.new.to_s}" }
    field :label, type: String
    field :type, type: String, default: 'string'
    field :many, type: Boolean, default: false
    field :required, type: Boolean, default: true
    field :description, type: String
    embeds_many :properties_locations, class_name: Setup::PropertyLocation.to_s, inverse_of: :pull_parameter

    accepts_nested_attributes_for :properties_locations, allow_destroy: true

    embedded_in :shared_collection, class_name: Setup::CrossSharedCollection.to_s, inverse_of: :pull_parameters

    validates_presence_of :label, :properties_locations
    validates_length_of :label, maximum: 255
    validates_uniqueness_of :label

    def process_on(hash_data, options = {})
      options ||= {}
      errors.clear
      properties_locations.each do |property_location|
        property_location.errors.clear
        location = property_location.location
        property_name = property_location.property_name
        if location.is_a?(Hash)
          if location.present?
            obj = hash_data
            location.each do |key, criteria|
              obj = obj && (obj = obj[key]) && (criteria ? Cenit::Utility.find_record(criteria, obj) : obj)
            end
            if obj
              if property_name.present?
                if (value = options[:value]).nil?
                  obj.delete(property_name) unless options[:keep_values]
                else
                  obj[property_name] = value
                end
              else
                property_location.errors.add(:property_name, "can't be blank")
              end
            else
              property_location.errors.add(:location, "can not locate value with #{location.to_json}")
            end
          else
            property_location.errors.add(:location, "can't be blank")
          end
        else
          property_location.errors.add(:location, 'is not a valid JSON object')
        end
        if property_location.errors.present?
          errors.add(:properties_locations, "contains invalid location for property '#{property_name}'")
        end
      end
      errors.blank?
    end

    BASIC_TYPES =
      {
        integer: 'integer',
        number: 'number',
        boolean: 'boolean',
        string: 'string',
        'cenit-oauth-scope': { type: 'string', format: 'cenit-oauth-scope' },
        'cenit-access-scope': { type: 'string', format: 'cenit-access-scope' },
        object: 'object',
        json: { oneOf: [{ type: 'object' }, { type: 'array' }] }
      }.deep_stringify_keys


    def type_enum
      BASIC_TYPES.keys.to_a +
        Setup::Collection.reflect_on_all_associations(:has_and_belongs_to_many).collect { |r| r.name.to_s.singularize.to_title }
    end

    def schema
      # TODO: Factorize code with algorithms and applications parameters
      sch =
        if type.blank?
          {}
        elsif (json_type = BASIC_TYPES[type])
          json_type.is_a?(Hash) ? json_type : { type: json_type }
        else
          {
            '$ref': case (klass = Setup::Collection.reflect_on_association(type.to_s.downcase.tr(' ', '_').pluralize).klass)
                    when Setup::RemoteOauthClient
                      Setup::OauthClient
                    when Setup::PlainWebhook
                      Setup::Webhook
                    else
                      klass
                    end.to_s
          }
        end
      sch = (many ? { type: 'array', items: sch } : sch)
      sch[:referenced] = true unless BASIC_TYPES.has_key?(type) || type.blank?
      sch[:description] = description if description.present?
      sch[:title] = label
      sch.deep_stringify_keys
    end
  end
end
