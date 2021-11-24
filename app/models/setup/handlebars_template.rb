module Setup
  class HandlebarsTemplate < Template
    include BulkableTransformation
    include SnippetCodeTemplate

    build_in_data_type.referenced_by(:namespace, :name)

    def execute(options)
      handlebars = Handlebars::Handlebars.new
      locals =
        if bulk_source
          {
            sources: options[:sources],
            items: options[:sources]
          }
        else
          options[:source].to_hash(include_id: true)
        end
      handlebars.compile(options[:code]).call(locals)
    end
  end
end
