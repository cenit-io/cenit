module Setup
  class LiquidConverter < ConverterTransformation
    include WithSourceOptions
    include SnippetCodeTransformation
    include RailsAdmin::Models::Setup::LiquidConverterAdmin

    def code_extension
      JSON.parse(code)
      '.json'
    rescue
      if Nokogiri::XML(code).errors.blank?
        '.xml'
      else
        '.txt'
      end
    end

    def execute(options)
      template = Liquid::Template.parse(options[:code])
      result = template.render(options.with_indifferent_access)
      options[:target] = options[:target_data_type].new_from(result)
    end
  end
end
