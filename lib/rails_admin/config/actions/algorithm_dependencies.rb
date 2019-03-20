module RailsAdmin
  module Config
    module Actions
      class AlgorithmDependencies < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :link_icon do
          'fa fa-external-link'
        end

        register_instance_option :controller do
          proc do
            if request.post?
              lang = algorithm_langs.select { |l| l[:id] == params[:lang_id] }.first
              result = puch_dependencies(lang, params[:dependencies])
              render json: result
            else
              warning = "<h4>Warning:</h4>"
              warning << "<ul>"
              warning << "<li>This configuration is used to execute all the algorithms written under this language.</li>"
              warning << "<li>Do not modify this file if you are not sure what you are doing.</li>"
              warning << "<li>Keep in mind that deleting or updating dependencies may cause some algorithms to fail.</li>"
              warning << "</ul>"

              flash[:warning] = warning.html_safe
            end
          end
        end
      end
    end
  end
end
