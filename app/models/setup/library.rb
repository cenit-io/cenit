module Setup
  class Library
    include CenitScoped

    Setup::Models.exclude_actions_for self, :edit, :update, :delete, :bulk_delete, :delete_all

    BuildInDataType.regist(self).embedding(:schemas).referenced_by(:name)

    field :name, type: String

    has_many :schemas, class_name: Setup::Schema.to_s, inverse_of: :library, dependent: :destroy

    validates_presence_of :name
    validates_account_uniqueness_of :name

    def find_data_type_by_name(name)
      if data_type = DataType.where(name: name).detect { |data_type| data_type.schema && data_type.schema.library == self }
        data_type
      else
        if (schema = Schema.where(uri: name).detect { |schema| schema.library == self }) && schema.data_types.count == 1
          schema.data_types.first
        else
          nil
        end
      end
    end
  end
end
