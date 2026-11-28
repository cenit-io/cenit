module Setup
  class LiquidConverter < ConverterTransformation
    include TemplateConverter

    build_in_data_type.referenced_by(:namespace, :name)

    def execute(options)
      Setup::Transformation::LiquidRendering.convert(options)
    end
  end
end
