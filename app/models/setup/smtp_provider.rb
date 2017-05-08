module Setup
  class SmtpProvider
    include CenitScoped
    include RailsAdmin::Models::Setup::SmtpProviderAdmin

    has_one :email_notifications, :class_name => Setup::ForeignNotificationEmail.name, :inverse_of => :smtp_provider

    build_in_data_type.protecting(:user_name, :password)

    field :address, type: String, :default => 'smtp.gmail.com'
    field :port, type: Integer, :default => 587
    field :domain, type: String, :default => 'gmail.com'
    field :user_name, type: String
    field :password, type: String
    field :authentication, type: Symbol, :default => :plain
    field :enable_starttls_auto, type: Boolean, :default => true
    field :from, type: String

    def authentication_enum
      {
        'None' => :none,
        'Plain' => :plain,
        'Login' => :login,
        'Cram md5' => :cram_md5,
      }
    end

    def label
      user_name =~ /@/ ? user_name : "#{user_name}@#{domain || address}"
    end
  end
end
