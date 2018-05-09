module Setup
  class RubyParser < ParserTransformation
    include RubyCodeTransformation
    include RailsAdmin::Models::Setup::RubyParserAdmin

    build_in_data_type.referenced_by(:namespace, :name)

  end
end
