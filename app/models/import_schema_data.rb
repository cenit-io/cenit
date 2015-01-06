class ImportSchemaData
  include Mongoid::Document

  field :base_uri, type: String
  field :file, type: String

  rails_admin do
    visible false

    edit do
      field :base_uri

      field :file do
        render do
          bindings[:form].file_field(self.name, self.html_attributes.reverse_merge({ data: { fileupload: true }}))
        end
      end
    end
  end
end