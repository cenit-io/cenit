module Setup
  class CenitDataType < DataType
    include RailsAdmin::Models::Setup::CenitDataTypeAdmin

    origins :cenit, -> { (Thread.current[:cenit_initializing] || Cenit::MultiTenancy.tenant_model.current_super_admin?) ? :tmp : nil }

    default_origin :tmp

    build_in_data_type.referenced_by(:namespace, :name).with(:namespace, :name, :title, :_type, :snippet, :events, :before_save_callbacks, :records_methods, :data_type_methods)
    build_in_data_type.and(
      properties: {
        schema: {
          type: 'object'
        },
        slug: {
          type: 'string'
        }
      }
    )

    def validates_for_destroy
      if Cenit::MultiTenancy.tenant_model.current_super_admin?
        unless origin == :tmp || (build_in_dt = build_in).nil?
          errors.add(:base, "#{custom_title} can not be destroyed because model #{build_in_dt.model} is present.")
        end
      else
        errors.add(:base, 'You are not authorized to execute this action.')
      end
      errors.blank?
    end

    def do_configure_when_save?
      !new_record? && !Cenit::MultiTenancy.tenant_model.current_super_admin?
    end

    def attribute_writable?(name)
      ((name == 'name') && Cenit::MultiTenancy.tenant_model.current_super_admin?) || super
    end

    def data_type_name
      if namespace.present?
        "#{namespace}::#{name}"
      else
        name
      end
    end

    def build_in
      Setup::BuildInDataType[data_type_name]
    end

    def find_data_type(ref, ns = namespace)
      super || build_in.find_data_type(ref, ns)
    end

    delegate :title, :schema, :subtype?, to: :build_in, allow_nil: true

    def data_type_storage_collection_name
      if (model = records_model).is_a?(Class)
        model = model.mongoid_root_class
      end
      Account.tenant_collection_name(model)
    end

    def method_missing(symbol, *args)
      if build_in.respond_to?(symbol)
        build_in.send(symbol, *args)
      else
        super
      end
    end
  end
end
