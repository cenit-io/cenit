module Setup
  class SmtpAccount < EmailChannel
    include CenitScoped

    build_in_data_type.protecting(:password).referenced_by(:provider, :user_name, :_type)

    belongs_to :provider, class_name: Setup::SmtpProvider.to_s, inverse_of: nil

    field :user_name, type: String
    field :password, type: String
    field :authentication, type: Symbol, default: :plain
    field :from, type: String

    validates_presence_of :provider
    validates_uniqueness_of :user_name, scope: :provider

    delegate :address, :port, :domain, to: :provider, allow_nil: true

    before_validation do
      if provider
        if user_name.present?
          self.namespace = 'SMTP Account'
          self.name = email_address
        else
          self.namespace = nil
          self.name = provider.custom_title
        end
      else
        self.namespace = self.name = nil
      end
    end

    def email_address
      @email_address ||
        (user_name.presence && (user_name =~ /@/ ? user_name : "#{user_name}@#{domain.presence || address}"))
    end

    def email_address=(email)
      @email_address = email = email.to_s
      if (match = email.match(/\A([^@]+)@(.+)\Z/))
        self.user_name ||= match[1]
        self.provider ||= Setup::SmtpProvider.where(domain: match[2]).first
        self.from = email
      else
        self.user_name = email
      end
    end

    def ready_to_save?
      provider.present?
    end

    def authentication_enum
      {
        None: :none,
        Plain: :plain,
        Login: :login,
        'Cram md5': :cram_md5
      }
    end

    def send_message(message)
      mail = Mail.new
      mail.from = message.from || from
      mail.to = message.to
      mail.subject = message.subject
      mail.body = message.body

      if message.attachments.any?
        attachments.each do |attachment|
          mail.add_file(
            filename: attachment.filename,
            content: attachment.data
          )
          mail.parts.last.content_type = attachment.contentType
        end
        mail.parts.first.content_type = 'text/html'
      else
        mail.content_type = 'text/html'
      end

      mail.delivery_method(:smtp, smtp_settings)
      mail.deliver
    end

    def smtp_settings
      settings = {}
      if provider
        %w(address port domain enable_starttls_auto).each do |key|
          settings[key.to_sym] = provider.send(key)
        end
      end
      unless authentication == :none
        %w(authentication user_name password).each do |key|
          settings[key.to_sym] = send(key)
        end
      end
      settings
    end

    protected :smtp_settings
  end
end
