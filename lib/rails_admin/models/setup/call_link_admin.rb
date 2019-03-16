module RailsAdmin
  module Models
    module Setup
      module CallLinkAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do
            visible false
            edit do
              field :name do
                help { nil }
                label 'Call name'
                html_attributes do
                  { readonly: true }
                end
              end
              field :link do
                inline_add false
                inline_edit false
                help { nil }
              end
            end

            fields :name, :link
          end
        end
      end
    end
  end
end
