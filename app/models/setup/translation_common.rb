module Setup
  module TranslationCommon
    extend ActiveSupport::Concern

    included do
      belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

      before_save do
        self.translator = Setup::Translator.where(id: message[:translator_id]).first if translator.blank?
      end
    end

    def run(message)
      if translator = Setup::Translator.where(id: translator_id = message[:translator_id]).first
        begin
          send('translate_' + translator.type.to_s.downcase, message)
        rescue ::Exception => ex
          fail "Error executing translator '#{translator.custom_title}' (#{ex.message})"
        end
      else
        fail "Translator with id #{translator_id} not found"
      end
    end

    protected

    def object_ids_from(message)
      message[:object_ids] || message[:bulk_ids]
    end

    def objects_from(message)
      model = data_type_from(message).records_model
      if object_ids = object_ids_from(message)
        model.any_in(id: object_ids)
      else
        model.all
      end
    end

    attr_reader :data_type

    def data_type_from(message)
      @data_type =
        if data_type_id = message['data_type_id']
          Setup::BuildInDataType.build_ins[data_type_id] || Setup::DataType.where(id: data_type_id).first ||
            fail("Data type with id #{data_type_id} not found")
        else
          fail 'Invalid message: data type ID is missing'
        end
    end

  end
end