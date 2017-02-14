module RailsAdmin
  ###
  # Features to admin and process the notebooks.
  module NotebooksHelper

    def notebooks_jupyter_url
      login = Account.current || User.current
      base_url = ENV['JUPYTER_NOTEBOOKS_URL'] || "http://127.0.0.1:8888"
      ns, model_name = api_model

      if model_name == 'notebook'
        url = "#{base_url}/tree/#{login.key}/#{login.token}"
      elsif params[:notebook].present?
        nb = Setup::Notebook.find(params[:notebook])
        url = "#{base_url}/notebooks/#{login.key}/#{login.token}/#{nb.path}"
      else
        url = "#{base_url}/tree/#{login.key}/#{login.token}/#{ns}/#{model_name}"
      end

      url
    end

    def index_setup_notebook
      render :layout => 'rails_admin/application_notebooks', :template => 'rails_admin/main/notebooks'
    end

    def show_setup_notebook
      redirect_to rails_admin.index_path(model_name: 'notebook', notebook: @object.id)
    end

    def new_setup_notebook
      redirect_to rails_admin.index_path(model_name: 'notebook')
    end

  end
end

