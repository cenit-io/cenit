module RailsAdmin
  module Models
    module Setup
      module SmtpAccountAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            navigation_label 'Workflows'
            object_label_method { :email_address }
            label 'SMTP Account'

            configure :from, :string do
              label 'Send email as'
            end

            configure :email_address

            edit do
              field :provider do
                visible do
                  bindings[:object].user_name.present? || bindings[:object].provider.present?
                end
              end
              field :authentication do
                visible do
                  bindings[:object].provider.present?
                end
              end
              field :email_address, :string do
                required true
                visible do
                  bindings[:object].user_name.blank? && bindings[:object].provider.blank?
                end
              end
              field :user_name, :string do
                visible do
                  bindings[:object].user_name.present? || bindings[:object].provider.present?
                end
              end
              field :password, :password do
                visible do
                  bindings[:object].user_name.present? || bindings[:object].provider.present?
                end
              end
              field :from, :string do
                visible do
                  bindings[:object].user_name.present? || bindings[:object].provider.present?
                end
              end
            end

            fields :provider, :user_name, :authentication, :from
          end
        end

      end
    end
  end
end
