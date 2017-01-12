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
              puch_dependencies(lang, params[:dependencies])
            end
          end
        end
      end

    end
  end
end
