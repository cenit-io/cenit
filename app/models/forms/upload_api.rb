module Forms
  class UploadApi
    include Mongoid::Document

    field :data, type: String
    field :file, type: String

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }

      edit do
        field :file do
          render do
            bindings[:form].file_field(self.name, self.html_attributes.reverse_merge(data: { fileupload: true }))
          end
        end

        field :data do
          html_attributes do
            {cols: '74', rows: '15'}
          end
        end
      end

    end
  end
end
