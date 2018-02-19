module Setup
  module SnippetCodeTemplate
    include SnippetCodeTransformation

    def code_extension
      file_extension.presence || ''
    end
  end
end
