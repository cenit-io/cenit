module Setup
  class FileStoreMigration < Setup::Task
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
          total = data_type.all.count.to_f
          processed = 0
          if (file_store = message[:file_store])
            file_store = file_store.to_s.constantize
            unless file_store == data_type.file_store
              data_type.all.each do |file|
                if data_type.file_store.stored?(file)
                  file_store.save(file, file.data, public_read: false)
                  data_type.file_store.destroy(file)
                end
                processed += 1
                update(progress: 89 * processed / total)
              end
              config.file_store = file_store
            end
          end
          update(progress: 90)
          processed = 0
          if message.key?('public_read')
            if (status = message[:public_read].to_s.to_b) || file_store.nil?
              file_store ||= data_type.file_store
              data_type.all.each do |file|
                file_store.set_public_read(file, status)
                processed += 1
                update(progress: 90 + 10 * processed / total)
              end
            end
            config.public_read = status
          end
          config.save(skip_migration: true)
        rescue ::Exception => ex
          Setup::SystemNotification.create_from(ex)
          fail "Error migrating data type #{data_type.custom_title} to file store #{message[:file_store]}: #{ex.message}"
        end
      else
        fail "File Data Type with ID #{data_type_id} not found"
      end
    end

    class << self

      def migrating?(data_type)
        Setup::FileStoreMigration.where(:status.in => Setup::Task::ALIVE_STATUS, data_type: data_type).present?
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
