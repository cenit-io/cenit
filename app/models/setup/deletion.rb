module Setup
  class Deletion < Setup::Task
    include BulkableTask

    build_in_data_type

    def run(message)
      data_type = data_type_from(message)
      if data_type
        if data_type.bulkable_deletable?
          if (model = data_type.records_model)
            scope = objects_from(message)
            destroy_callback = data_type.is_a?(FileDataType) ||
              begin
                model.send(:get_callbacks, :destroy).present?
              rescue
                false
              end
            if destroy_callback
              progress_step = 10
              step_size = scope.count / progress_step
              step_count = 0
              scope.each do |record|
                record.destroy unless record == self
                step_count += 1
                next unless step_count >= step_size
                step_count = 0
                self.progress += progress_step
                save
              end
            else
              if scope.is_a?(Mongoid::Criteria)
                scope.delete_all
              else
                scope.delete_many
              end
            end
          else
            fail "Can not determine records model from name '#{data_type.custom_title}'"
          end
        else
          fail "Can not bulk delete records on '#{data_type.custom_title}'"
        end
      else
        fail "Can not resolve data type"
      end
    end

  end
end
