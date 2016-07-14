module RailsAdmin
  module Config
    module Actions
      class Copy < RailsAdmin::Config::Actions::Base

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do

            model = abstract_model.model rescue nil
            if model
              attrs = @object.attributes.deep_dup #TODO Exclude protected attributes
              redirect_to rails_admin.new_path(model_name: model.to_s.underscore.gsub('/', '~'), params: { attributes: attrs.to_json })
            else
              redirect_to back_or_index
            end

          end
        end

        register_instance_option :link_icon do
          'fa fa-files-o'
        end
      end
    end
  end
end