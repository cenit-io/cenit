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

    field :file_store, type: Module, default: -> { self.class.default_file_store_for(data_type) }
    field :public_read, type: Mongoid::Boolean, default: -> { self.class.default_public_option_for(data_type) }

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

      def default_file_store_for(file_data_type)
        if file_data_type && (model = file_data_type.records_model).is_a?(Class) && model < BuildInFileType
          file_store_name = ENV["#{model}:file_store"]
          Cenit.file_stores.detect { |file_store| file_store.to_s == file_store_name } ||
            Cenit.default_file_store
        else
          Cenit.default_file_store
        end
      end

      def default_public_option_for(file_data_type)
        if file_data_type && (model = file_data_type.records_model).is_a?(Class) && model < BuildInFileType
          model.public_by_default
        else
          false
        end
      end
    end
  end
end
