module Setup
  module TemplateConverter
    extend ActiveSupport::Concern

    include WithSourceOptions
    include SnippetCodeTransformation

    def code_extension
      JSON.parse(code)
      '.json'
    rescue
      if Nokogiri::XML(code).errors.blank?
        '.xml'
      else
        '.txt'
      end
    end
  end
end
