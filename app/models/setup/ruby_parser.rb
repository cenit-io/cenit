module Setup
  class RubyParser < ParserTransformation
    include RubyCodeTransformation
    include RailsAdmin::Models::Setup::RubyParserAdmin

  end
end
