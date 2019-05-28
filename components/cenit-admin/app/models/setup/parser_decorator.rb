module Setup
  Parser.class_eval do
    include RailsAdmin::Models::Setup::ParserAdmin
  end
end
