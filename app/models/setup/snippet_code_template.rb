module Setup
  module SnippetCodeTemplate
    extend ActiveSupport::Concern

    include SnippetCodeTransformation

    def build_execution_options(options)
      options = super
      options[:code] = code
      options
    end

    def code_extension
      file_extension.presence || ''
    end
  end
end
