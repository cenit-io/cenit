module Setup
  class HandlebarsTemplate < Template
    include BulkableTransformation
    include SnippetCodeTemplate
    include RailsAdmin::Models::Setup::HandlebarsTemplateAdmin

    build_in_data_type.referenced_by(:namespace, :name)

    def execute(options)
      handlebars = Handlebars::Context.new
      locals =
        if bulk_source
          handlebars.register_helper(:each_source) do |_, block|
            r = ''
            #TODO Build brake condition using Capataz maximum_iterations
            options[:sources].each do |item|
              r += "#{block.fn(item.to_hash(include_id: true))}"
            end
            r
          end
          {}
        else
          options[:source].to_hash(include_id: true)
        end
      handlebars.compile(options[:code]).call(locals)
    end
  end
end
