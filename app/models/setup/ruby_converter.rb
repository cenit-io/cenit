module Setup
  class RubyConverter < ConverterTransformation
    include WithSourceOptions
    include RubyCodeTransformation
    include RailsAdmin::Models::Setup::RubyConverterAdmin

    field :source_handler, type: Boolean

    def validates_configuration
      unless source_handler
        remove_attribute(:source_handler)
        errors.add(:target_data_type, "can't be blank (source handler is not checked)") unless target_data_type
      end
      super
    end

    def base_execution_options(options)
      opts = super
      opts[:target] = target_data_type.records_model.new unless source_handler
      opts
    end

    def source_key_options
      opts = super
      opts[:bulk] = source_handler
      opts
    end
  end
end
