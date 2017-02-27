module Forms
  class ImportApiSpec
    include Mongoid::Document

    field :base_url, type: String
    field :data, type: String

    validates_presence_of :data

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :base_url
        field :data do
          render do
            bindings[:form].file_field(self.name, self.html_attributes.reverse_merge(data: { fileupload: true }))
          end
        end
      end
    end
  end
end
