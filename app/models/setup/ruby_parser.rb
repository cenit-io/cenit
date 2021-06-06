module Setup
  class RubyParser < ParserTransformation
    include RubyCodeTransformation

    build_in_data_type.referenced_by(:namespace, :name)

  end
end
