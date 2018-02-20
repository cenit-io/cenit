module Setup
  class LiquidTemplate < Template
    include SnippetCodeTemplate
    include RailsAdmin::Models::Setup::LiquidTemplateAdmin

    def execute(options)
      template = Liquid::Template.parse(options[:code])
      source_hash = options[:source].to_hash(include_id: true)
      template.render(source_hash)
    end
  end
end
