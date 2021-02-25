module Setup
  class FileStoreConfig
    include CenitScoped

    deny :all

    build_in_data_type.and(
      properties: {
        file_store: {
          enum: Cenit.file_stores.map(&:to_s),
          enumNames: Cenit.file_stores.map(&:label)
        },
        migration_enabled: {
          type: 'boolean',
          virtual: true
        },
        migration_in_progress: {
          type: 'boolean',
          virtual: true
        }
      }
    )

    belongs_to :data_type, class_name: Setup::FileDataType.to_s, inverse_of: nil

    field :file_store, type: Module, default: -> { Cenit.default_file_store }
    field :public_read, type: Boolean, default: false

    attr_readonly :data_type

    validates_presence_of :data_type, :file_store

    before_save do
      start_migration unless @skip_migration_callback
    end

    def start_migration
      if persisted? && (changed_attributes.key?('file_store') || changed_attributes.key?('public_read'))
        if Setup::FileStoreMigration.cannot_migrate?(data_type)
          errors.add(:file_store, 'can not be updated')
        else
          msg = { data_type_id: data_type_id }
          if changed_attributes.key?('file_store')
            msg[:file_store] = file_store.to_s
            reset_attribute!('file_store')
          end
          if msg.key?(:file_store) || changed_attributes.key?('public_read')
            msg[:public_read] = public_read.to_s
            reset_attribute!('public_read')
          end
          Setup::FileStoreMigration.process(msg)
        end
      end
      errors.blank?
    end

    def save(options = {})
      @skip_migration_callback = options.delete(:skip_migration)
      super
      @skip_migration_callback = false
    end

    def migration_enabled
      FileStoreMigration.enabled?
    end

    def migration_in_progress
      FileStoreMigration.migrating?(data_type)
    end

    class << self
      def file_store_enum
        Cenit.file_stores.map { |fs| [fs.label, fs] }.to_h
      end
    end
  end
end
