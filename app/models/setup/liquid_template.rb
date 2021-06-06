module Setup
  class LiquidTemplate < Template
    include SnippetCodeTemplate

    build_in_data_type.referenced_by(:namespace, :name)

    def execute(options)
      template = Liquid::Template.parse(options[:code])
      source_hash = options[:source].to_hash(include_id: true)
      template.render(source_hash)
    end
  end
end
