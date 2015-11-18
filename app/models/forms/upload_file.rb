module Forms
  class UploadFile
    include Mongoid::Document

    field :file, type: String

    validates_presence_of :file

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do

        field :file do
          render do
            bindings[:form].file_field(self.name, self.html_attributes.reverse_merge(data: {fileupload: true}))
          end
        end

      end
    end
  end
end