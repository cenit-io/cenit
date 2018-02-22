module Setup
  class RubyTemplate < Template
    include RubyCodeTemplate
    include RailsAdmin::Models::Setup::RubyTemplateAdmin

  end
end
