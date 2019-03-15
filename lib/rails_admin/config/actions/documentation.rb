module RailsAdmin
  module Config
    module Actions
      class Documentation < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get]
        end

        register_instance_option :link_icon do
          'fa fa-file-text'
        end

        register_instance_option :controller do
          proc do
            model_name = @abstract_model.pretty_name.downcase.pluralize
            category = RailsAdmin::Config.model(@abstract_model.model).navigation_label.downcase
            url = "#{ENV['DOCS_URL'] || 'http://cenit-io.github.io'}/docs/#{category}/#{model_name}"
            redirect_to url
          end
        end
      end
    end
  end
end
