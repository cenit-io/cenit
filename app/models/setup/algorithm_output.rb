module Setup
  class AlgorithmOutput
    include CenitScoped
    # = Algorithm Output
    #
    # Allow the associate a Data Type with the output of an algorithm.

    build_in_data_type

    deny :new, :edit, :copy, :update

    belongs_to :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil
    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :input_params, type: Hash

    field :output_ids, type: Array

    after_destroy :clean_records

    def clean_records
      data_type.records_model.where(:id.in => output_ids).delete_many
    end

    def name
      "#{algorithm.custom_title} @ #{created_at}"
    end

    def records(_options = {})
      data_type.records_model.where(:id.in => output_ids)
    end

    def records_count
      "#{output_ids.size} records"
    end

    def input_parameters
      input_params.to_json
    end

  end
end
