module Setup
  class AlgorithmOutput
    include CenitScoped

    build_in_data_type

    deny :edit, :copy, :simple_export

    belongs_to :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil
    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil

    field :output_ids, type: Array

    after_destroy :clean_records

    def clean_records
      data_type.records_model.where(:id.in => output_ids).delete_many
    end

    def name
      "#{algorithm.custom_title} @ #{created_at}"
    end

    def records(options = {})
      data_type.records_model.where(:id.in => output_ids)
    end

    def records_count
      "#{output_ids.size} records"
    end

  end
end