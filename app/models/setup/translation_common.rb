module Setup
  module TranslationCommon
    extend ActiveSupport::Concern

    include Setup::BulkableTask

    included do
      belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

      before_save do
        self.translator = Setup::Translator.where(id: message[:translator_id]).first if translator.blank?
      end
    end

    def run(message)
      if (translator = Setup::Translator.where(id: (translator_id = message[:translator_id])).first)
        begin
          send('translate_' + translator.type.to_s.downcase, message)
        rescue ::Exception => ex
          fail "Error executing translator '#{translator.custom_title}' (#{ex.message})"
        end
      else
        fail "Translator with id #{translator_id} not found"
      end
    end
  end
end