module Setup
  class Deletion < Setup::Task

    BuildInDataType.regist(self)

    def deletion_model
      model_name = message[:model_name.to_s]
      unless model = model_name.constantize rescue nil
        if model_name.start_with?('Dt') && data_type = Setup::DataType.where(id: model_name.from(2)).first
          model = data_type.records_model
        end
      end
      model
    end

    def run(message)
      if model = deletion_model
        scope = model.where(message[:selector])
        if (model.singleton_method(:before_destroy) rescue nil)
          progress_step = 10
          step_size = scope.count / progress_step
          step_count = 0
          scope.each do |record|
            record.destroy unless record == self
            step_count += 1
            if step_count >= step_size
              step_count = 0
              self.progress += progress_step
              save
            end
          end
        else
          if scope.is_a?(Mongoid::Criteria) then
            scope.delete_all
          else
            scope.delete_many
          end
        end
      else
        fail "Can not determine records model from name '#{model_name}'"
      end
    end
  end
end
