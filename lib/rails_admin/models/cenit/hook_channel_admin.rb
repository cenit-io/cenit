module RailsAdmin
  module Models
    module Cenit
      module HookChannelAdmin
        extend ActiveSupport::Concern

        included do
          rails_admin do

            object_label_method { :label }

            fields :slug, :data_type
          end
        end
      end
    end
  end
end
