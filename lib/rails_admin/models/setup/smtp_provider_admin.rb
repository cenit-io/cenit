module RailsAdmin
  module Models
    module Setup
      module SmtpProviderAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Security'
            parent ::Setup::AuthorizationProvider
            object_label_method { :custom_title }
            weight 331
            label 'SMTP provider'
            register_instance_option :label_navigation do
              'SMTP'
            end

            configure :namespace, :enum_edit

            configure :address, :string do
              label 'SMTP Host'
              required true
            end

            configure :enable_starttls_auto, :boolean do
              label 'Auto Start TLS'
            end

            edit do
              field :namespace
              field :name
              field :address
              field :port do
                required true
              end
              field :domain, :string
              field :enable_starttls_auto
            end

            fields :namespace, :name, :address, :port, :domain, :enable_starttls_auto
          end
        end
      end
    end
  end
end
