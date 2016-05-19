module RailsAdmin
  module Config
    module Actions
      class Gist < RailsAdmin::Config::Actions::Base

        register_instance_option :only do
          Setup::Algorithm
        end

        register_instance_option :member do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :controller do
          proc do
            redirect_to "http://gist.github.com/" + Cenit.github_shared_collections_user + "/" + @object.gist_id, target: '_blank'
          end
        end

        register_instance_option :link_icon do
          'fa fa-file-code-o'
        end

        register_instance_option :pjax do
          false
        end
      end
    end
  end
end