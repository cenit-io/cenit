module Forms
  class ImportSchemaData
    include Mongoid::Document

    belongs_to :library, class_name: Setup::Library.to_s
    field :file, type: String
    field :base_uri, type: String

    validates_presence_of :library, :file

    rails_admin do
      visible false

      edit do

        field :library do
          inline_edit false
        end

        field :file do
          render do
            bindings[:form].file_field(self.name, self.html_attributes.reverse_merge(data: {fileupload: true}))
          end
        end

        field :base_uri
      end
    end
  end
end
