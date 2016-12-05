module Setup
  class StoredProcedureOutput
    include CenitScoped

    build_in_data_type

    deny :edit, :copy, :simple_export

    belongs_to :stored_procedure, class_name: Setup::StoredProcedure.to_s, inverse_of: nil
    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :input_params, type: Hash

    field :output_ids, type: Array

    after_destroy :clean_records

    def clean_records
      data_type.records_model.where(:id.in => output_ids).delete_many
    end

    def name
      "#{stored_procedure.custom_title} @ #{created_at}"
    end

    def records
      data_type.records_model.where(:id.in => output_ids)
    end

    def input_parameters
      input_params.to_json
    end

  end
end