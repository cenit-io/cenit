module Setup
  module TemplateConverter
    extend ActiveSupport::Concern

    include WithSourceOptions
    include SnippetCodeTransformation

    included do

      validates_presence_of :target_data_type

    end

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
