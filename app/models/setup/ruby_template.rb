module Setup
  class RubyTemplate < Template
    include RubyCodeTemplate

    build_in_data_type.referenced_by(:namespace, :name)

  end
end
