module Setup
  class Renderer < Translator
    include RailsAdmin::Models::Setup::RendererAdmin

    transformation_type :Export
    allow :new

    has_one :email_notifications, :class_name => Setup::ForeignNotificationEmail.name, :inverse_of => :body_template
    belongs_to :email_notifications, :class_name => Setup::ForeignNotificationEmail.name, :inverse_of => :attachments_templates

    build_in_data_type.with(:namespace, :name, :source_data_type, :style, :bulk_source, :mime_type, :file_extension, :snippet ).referenced_by(:namespace, :name)

  end
end
