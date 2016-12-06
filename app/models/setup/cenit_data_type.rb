module Setup
  class CenitDataType < DataType

    origins :cenit

    default_origin :cenit

    build_in_data_type.referenced_by(:namespace, :name).with(:namespace, :name, :title, :_type, :snippet, :events, :before_save_callbacks, :records_methods, :data_type_methods)
    build_in_data_type.and({
                             properties: {
                               schema: {
                                 type: 'object'
                               },
                               slug: {
                                 type: 'string'
                               }
                             }
                           }.deep_stringify_keys)
    def data_type_name
      "#{namespace}::#{name}"
    end

    def build_in
      Setup::BuildInDataType[data_type_name]
    end

    delegate :title, :schema, :subtype?, to: :build_in
  end
end
