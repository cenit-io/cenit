module Setup
  class AlgorithmValidator < CustomValidator
    include SharedEditable
    include CenitScoped
    include RailsAdmin::Models::Setup::AlgorithmValidatorAdmin

    build_in_data_type.referenced_by(:namespace, :name)

    belongs_to :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil

    validates_presence_of :algorithm

    before_save :validates_configuration

    def validates_configuration
      errors.add(:algorithm, 'must receive one parameter') unless algorithm.parameters.size == 1
      super
    end

    def validate_data(data)
      fail NotImplementedError
    end

    def validate_file_record(file)
      begin
        algorithm.run(file)
      rescue Exception => ex
        [ex.message]
      end
    end
  end
end
