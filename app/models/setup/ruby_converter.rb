module Setup
  class RubyConverter < ConverterTransformation
    include WithSourceOptions
    include RubyCodeTransformation
    include RailsAdmin::Models::Setup::RubyConverterAdmin

    #TODO Target data type not required for source handled converters
    field :source_handler, type: Boolean

    def validates_configuration
      remove_attribute(:source_handler) unless source_handler
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
