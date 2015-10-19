module RailsAdmin
  module Config
    module Actions
      class Records < RailsAdmin::Config::Actions::Base

        register_instance_option :only? do
          [Setup::DataType, Setup::SchemaDataType, Setup::FileDataType]
        end

        register_instance_option :visible? do
          if authorized?
            bindings[:object].loaded?
          else
            false
          end
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do

            if @object.loaded?
              redirect_to rails_admin.index_path(model_name: @object.model.to_s.underscore.gsub('/', '~'))
            else
              redirect_to back_or_index
            end

          end
        end

        register_instance_option :link_icon do
          'icon-list'
        end
      end
    end
  end
end