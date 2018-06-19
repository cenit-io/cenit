module Setup
  class FileStoreMigration < Setup::Task
    include RailsAdmin::Models::Setup::FileStoreMigrationAdmin

    agent_field :data_type

    build_in_data_type

    belongs_to :data_type, class_name: Setup::FileDataType.to_s, inverse_of: nil

    before_save do
      self.data_type = Setup::FileDataType.where(id: message[:data_type_id]).first unless data_type
    end

    def run(message)
      if (data_type = Setup::FileDataType.where(id: (data_type_id = message[:data_type_id])).first)
        begin
          config = data_type.file_store_config
          if (file_store = message[:file_store])
            file_store = file_store.to_s.constantize
            data_type.all.each do |file|
              file_store.save(file, file.data, public_read: false)
              data_type.file_store.destroy(file)
            end
            config.file_store = file_store
          end
          if message.key?('public_read')
            if (status = message[:public_read].to_s.to_b) || file_store.nil?
              file_store ||= data_type.file_store
              data_type.all.each do |file|
                file_store.set_public_read(file, status)
              end
            end
            config.public_read = status
          end
          config.save(skip_migration: true)
        rescue ::Exception => ex
          fail "Error migrating data type #{data_type.custom_title} to file store #{message[:file_store]}: #{ex.message}"
        end
      else
        fail "File Data Type with ID #{data_type_id} not found"
      end
    end

    class << self

      def migrating?(data_type)
        Setup::FileStoreMigration.where(:status.in => Setup::Task::RUNNING_STATUS, data_type: data_type).present?
      end

      def enabled?
        (user = ::User.current) &&
          user.roles.any? { |role| ::Cenit.file_stores_roles.include?(role.name.to_s) }
      end

      def unable?
        !enabled?
      end

      def cannot_migrate?(data_type)
        unable? || migrating?(data_type)
      end
    end
  end
end
