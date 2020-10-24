module Setup
  class LiquidConverter < ConverterTransformation
    include TemplateConverter

    build_in_data_type.referenced_by(:namespace, :name)

    def execute(options)
      template = Liquid::Template.parse(options[:code])
      result = template.render(options.with_indifferent_access)
      options[:target] = options[:target_data_type].new_from(result)
    end
  end
end
