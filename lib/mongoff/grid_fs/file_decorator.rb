module Mongoff
  module GridFs
    module FileWithStore
      def self.included(base)
        base.class_eval do

          def file_store
            @file_store ||= (orm_model.data_type.store_in || 'Cenit::FileStore::LocalDb').constantize
          end

          def read(*args)
            file_store.read(self, *args) unless self.new_record?
          end

          def save(options = {})
            unless @new_data.nil?

              self[:metadata] = options[:metadata] || self[:metadata] || {}
              self[:encoding] = options[:encoding] || self[:encoding]
              self[:chunkSize] = [self[:chunkSize], FileModel::MINIMUM_CHUNK_SIZE].min
              self[:length] = @new_data.size

              if @new_data.is_a?(String)
                self[:filename] = options[:filename] || self[:filename]
                self[:contentType] = options[:contentType] || self[:contentType]
              else
                self[:filename] = options[:filename] || extract_basename(@new_data)
                self[:contentType] = options[:contentType] || extract_content_type_from_io(@new_data)
              end

              run_callbacks_and do
                file_data_errors = self.orm_model.data_type.validate_file(self) unless options[:valid_data]

                if file_data_errors.present?
                  errors.add(:base, "Invalid file data: #{file_data_errors.to_sentence}") if file_data_errors.present?
                else
                  begin
                    file_store.save(self, @new_data, options)
                  rescue Exception => ex
                    errors.add(:data, ex.message)
                  end
                end
              end
            else
              errors.add(:data, "can't be nil") if new_record?
            end

            super if errors.blank?
          end

          def destroy
            file_store.destroy(self)
            super
          end

        end
      end
    end

    Mongoff::GridFs::File.class_eval do
      send(:include, FileWithStore) unless included_modules.include?(FileWithStore)
    end
  end
end