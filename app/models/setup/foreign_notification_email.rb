module Setup
  class ForeignNotificationEmail < Setup::ForeignNotification
    include RailsAdmin::Models::Setup::ForeignNotificationEmailAdmin

    field :to, type: String
    field :subject, type: String
    field :body, type: String

    belongs_to :data_type, :class_name => Setup::DataType.name, :inverse_of => :email_notifications
    belongs_to :body_template, :class_name => Setup::Renderer.name, :inverse_of => nil
    belongs_to :attachment_template, :class_name => Setup::Renderer.name, :inverse_of => nil
    belongs_to :smtp_provider, :class_name => Setup::SmtpProvider.name, :inverse_of => :email_notifications

    allow :copy, :new, :edit, :export, :import

    # Send notification via email message
    def send_message(data)
      translator_options = render_options(data)
      mail = Mail.new
      mail.from = smtp_provider.from
      mail.to = render(data, to)
      mail.subject = render(data, subject)
      mail.body = body_template ? body_template.run(translator_options) : render(data, body)
     
      if attachment_template
        mail.add_file(
          :filename => "#{attachment_template.name.parameterize}.pdf",
          :content => attachment_template.run(translator_options)
        )
        mail.parts.first.content_type = 'text/html'
      else
        mail.content_type = "text/html"
      end

      mail.delivery_method(:smtp, smtp_settings)
      mail.deliver
    end

    protected

    def smtp_settings
      smtp_provider.to_hash.select do |k, _|
        %w(address port domain user_name password authentication enable_starttls_auto).include?(k)
      end.select do |k, _|
        (smtp_provider.authentication != :none) || !%w(authentication user_name password).include?(k)
      end.map { |k, v| [k.to_sym, v] }.to_h
    end
  end
end
