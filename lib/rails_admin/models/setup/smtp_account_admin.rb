module RailsAdmin
  module Models
    module Setup
      module SmtpAccountAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :label }
            label 'SMTP Account'

            visible { User.current_super_admin? }

            configure :from, :string do
              label 'Send email as'
              required true
            end

            edit do
              field :provider
              field :authentication
              field :user_name, :string
              field :password, :password
              field :from
            end

            fields :provider, :user_name, :authentication, :from
          end
        end

      end
    end
  end
end
