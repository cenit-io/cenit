module RailsAdmin
  module Models
    module Setup
      module SmtpProviderAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do |c|
            c.parent ::Setup::BaseOauthProvider
            object_label_method { :label }
            weight 331
            label 'SMTP'
            visible false

            c.configure :address, :string do
              label 'SMTP Host'
              required true
            end

            c.configure :enable_starttls_auto, :boolean do
              label 'Auto Start TLS'
            end

            c.configure :from, :string do
              label 'Send email as'
              required true
            end

            edit do
              field :address
              field :port do
                required true
              end
              field :domain, :string
              field :authentication
              field :user_name, :string
              field :password, :password
              field :enable_starttls_auto
              field :from
            end

            fields :address, :port, :domain, :user_name, :authentication, :enable_starttls_auto, :from
          end
        end

      end
    end
  end
end
