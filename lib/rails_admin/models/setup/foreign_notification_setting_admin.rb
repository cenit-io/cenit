module RailsAdmin
  module Models
    module Setup
      module ForeignNotificationSettingAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            object_label_method { :label }

            edit do
              # Email setting vars
              group :email do
                label 'E-Mail'
                field :send_email, :boolean do
                  label 'Send E-Mail?'
                end
                field :email_to, :string do
                  label 'To'
                end
                field :email_subject, :string do
                  label 'Subject'
                end
                field :email_body, :text do
                  label 'Body'
                end
              end

              # Http setting vars
              group :http_request do
                label 'HTTP Request'
                field :send_http_request, :boolean do
                  label 'Send HTTP Request?'
                end
                field :http_uri, :string do
                  label 'URI'
                end
                field :http_method do
                  label 'Method'
                end
                field :http_params do
                  label 'Params'
                end
              end

              # SMS setting vars
              group :SMS do
                label 'SMS'
                field :send_sms, :boolean do
                  label 'Send SMS?'
                end
                field :sms_to, :string do
                  label 'To'
                end
                field :sms_body, :text do
                  label 'Body'
                end
              end
            end

          end
        end

      end
    end
  end
end
