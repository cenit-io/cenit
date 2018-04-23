module Setup
  class LiquidConverter < ConverterTransformation
    include TemplateConverter
    include RailsAdmin::Models::Setup::LiquidConverterAdmin

    def execute(options)
      template = Liquid::Template.parse(options[:code])
      result = template.render(options.with_indifferent_access)
      options[:target] = options[:target_data_type].new_from(result)
    end
  end
end
