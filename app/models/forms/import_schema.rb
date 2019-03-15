module Forms
  class ImportSchema
    include Mongoid::Document

    field :namespace, type: String
    field :data, type: String
    field :base_uri, type: String

    validates_presence_of :namespace, :data

    rails_admin do
      visible false
      register_instance_option(:discard_submit_buttons) { true }
      edit do
        field :namespace, :enum_edit do
          enum do
            Setup::Namespace.all.collect(&:name)
          end
        end

        field :data do
          render do
            bindings[:form].file_field(self.name, self.html_attributes.reverse_merge(data: { fileupload: true }))
          end
        end

        field :base_uri
      end
    end
  end
end
