module Setup
  class FileStoreConfig
    include CenitScoped
    include RailsAdmin::Models::Setup::FileStoreConfigAdmin

    deny :all

    build_in_data_type

    belongs_to :data_type, class_name: Setup::FileDataType.to_s, inverse_of: nil

    field :file_store, type: Class, default: -> { Cenit.default_file_store }

    attr_readonly :data_type

    validates_presence_of :data_type, :file_store

    before_save do
      start_migration unless @skip_migration_callback
    end

    def start_migration
      if persisted? && changed_attributes.key?('file_store')
        if Setup::FileStoreMigration.cannot_migrate?(data_type)
          errors.add(:file_store, 'can not be updated')
        else
          target_file_store = file_store.to_s
          reset_attribute!('file_store')
          Setup::FileStoreMigration.process(data_type_id: data_type_id, file_store: target_file_store)
        end
      end
      errors.blank?
    end

    def save(options = {})
      @skip_migration_callback = options.delete(:skip_migration)
      super
      @skip_migration_callback = false
    end

    class << self
      def file_store_enum
        Cenit.file_stores.map { |fs| [fs.label, fs] }.to_h
      end
    end
  end
end
