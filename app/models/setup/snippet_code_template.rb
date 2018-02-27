module Setup
  module SnippetCodeTemplate
    extend ActiveSupport::Concern

    include SnippetCodeTransformation

    def code_extension
      file_extension.presence || ''
    end
  end
end
