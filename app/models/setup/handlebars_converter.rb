module Setup
  class HandlebarsConverter < ConverterTransformation
    include TemplateConverter
    include RailsAdmin::Models::Setup::HandlebarsConverterAdmin

    def execute(options)
      handlebars = Handlebars::Context.new
      result = handlebars.compile(options[:code]).call(source: options[:source].to_hash(include_id: true))
      options[:target] = options[:target_data_type].new_from(result)
    end
  end
end
