module Setup
  class ChartRendering < Setup::Task
    include ::RailsAdmin::Models::Setup::ChartRenderingAdmin

    build_in_data_type

    def run(message)
      if (data_type = Setup::DataType.where(id: data_type_id = message[:data_type_id]).first)
        klass = data_type.records_model
        all_objects = klass.where(message[:selector] || {})
        data = klass.data_by(all_objects, message[:met], message[:data_field], message[:calculation], message[:acumulate])[0][:data]
        sleep(10)
        current_execution.attach filename: 'data.json',
                                 contentType: 'application/json',
                                 body: data.to_json
      else
        fail "Data type with ID '#{data_type_id}' not found"
      end
    end
  end
end
