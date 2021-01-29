module Setup
  class Deletion < Setup::Task
    include BulkableTask

    build_in_data_type

    def run(message)
      if (model = data_type_from(message).records_model)
        scope = objects_from(message)
        destroy_callback = [:before_destroy, :after_destroy].any? do |m|
          begin
            model.singleton_method(m)
          rescue
            false
          end
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
        fail "Can not determine records model from name '#{target_model_name}'"
      end
    end

  end
end
