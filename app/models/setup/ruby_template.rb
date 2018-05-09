module Setup
  class RubyTemplate < Template
    include RubyCodeTemplate
    include RailsAdmin::Models::Setup::RubyTemplateAdmin

    build_in_data_type.referenced_by(:namespace, :name)

  end
end
