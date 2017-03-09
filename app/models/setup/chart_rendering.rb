module Setup
  class ChartRendering < Setup::Task
    include RailsAdmin::Models::Setup::ChartRenderingAdmin

    build_in_data_type

    def run(message)
      if (data_type = Setup::DataType.where(id: data_type_id = message[:data_type_id]).first)

      else
        fail "Data type with ID '#{data_type_id}' not found"
      end
    end
  end
end
