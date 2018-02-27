module Forms
  class ImportTranslatorSelector
    include DataImportCommon
    include TransformationOptions
    include AccountScoped

    belongs_to :data_type, class_name: Setup::DataType.to_s, inverse_of: nil
    belongs_to :translator, class_name: Setup::Translator.to_s, inverse_of: nil

    validates_presence_of :translator

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :translator do
          contextual_association_scope do
            proc { |scope| scope.and(:_type.in => [Setup::Parser, Setup::ParserTransformation.concrete_class_hierarchy].flatten.collect(&:to_s)) }
          end
          contextual_params do
            if (dt = bindings[:object].data_type)
              { target_data_type_id: [nil, dt.id] }
            end
          end
        end

        field :options

        field :file do
          render do
            bindings[:form].file_field(self.name, self.html_attributes.reverse_merge(data: { fileupload: true }))
          end
        end

        field :decompress_content

        field :data do
          html_attributes do
            { cols: '74', rows: '15' }
          end
        end
      end
    end
  end
end
