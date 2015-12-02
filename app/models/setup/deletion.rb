module Setup
  class Deletion < Setup::Task

    BuildInDataType.regist(self)

    def run(message)
      unless model_name = message[:model_name]
        fail 'Model name missing'
      end
      unless model = model_name.constantize rescue nil
        if model.name.start_with?('Dt') && data_type = Setup::DataType.where(id: name.from(2)).first
          model = data_type.records_model
        end
      end
      if model
        scope = model.where(message[:selector])
        if (model.singleton_method(:before_destroy) rescue nil)
          progress_step = 10
          step_size = scope.count / progress_step
          step_count = 0
          scope.each do |record|
            record.destroy
            step_count += 1
            if step_count >= step_size
              step_count = 0
              self.progress += progress_step
              save
            end
          end
        else
          scope.delete_all
        end
      else
        fail "Can not determine records model from name '#{model_name}'"
      end
    end
  end
end
