module RailsAdmin
  module Config
    module Actions
      class Notebooks < RailsAdmin::Config::Actions::Base

        register_instance_option :collection do
          true
        end

        register_instance_option :http_methods do
          [:get, :post]
        end

        register_instance_option :link_icon do
          'fa fa-book'
        end

        register_instance_option :controller do
          proc do
            # Generate rest-api doc as notebook.
            api_langs.each { |lang| api_notebook(lang) if lang[:runnable] }
            # Renter user interface of jupyter-notebook.
            #render :layout => 'rails_admin/application_notebooks' if @model_name == 'Setup::Notebook'
          end
        end
      end
    end
  end
end
