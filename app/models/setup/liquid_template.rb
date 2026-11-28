module Setup
  class LiquidTemplate < Template
    include SnippetCodeTemplate

    build_in_data_type.referenced_by(:namespace, :name)

    def execute(options)
      Setup::Transformation::LiquidRendering.export(options, include_id: true)
    end
  end
end
