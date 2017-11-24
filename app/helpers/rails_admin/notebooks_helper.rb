module RailsAdmin
  ###
  # Features to admin and process the notebooks.
  module NotebooksHelper

    include RailsAdmin::RestApi::Notebooks

    def notebooks_jupyter_url(notebook=nil)
      login = Account.current || User.current
      key, token = login ? [login.key, login.token] : ['-', '-']
      ns, model_name = api_model
      nb ||= Setup::Notebook.find(params[:notebook]) if params[:notebook].present?

      if model_name == 'notebook'
        url = "tree/#{key}/#{token}"
      elsif nb
        url = "notebooks/#{key}/#{token}/#{nb.path}"
      else
        url = "tree/#{key}/#{token}/REST-API/#{ns}/#{model_name}"
      end

      "#{Cenit.jupyter_notebooks_url}/#{url.gsub(/\/{2,}/,'/')}".chomp('/')
    end

    def index_setup_notebook
      render :layout => 'rails_admin/application', :template => 'rails_admin/main/notebooks'
    end

    def show_setup_notebook
      redirect_to rails_admin.index_path(model_name: 'notebook', notebook: @object.id)
    end

    def new_setup_notebook
      redirect_to rails_admin.index_path(model_name: 'notebook')
    end

  end
end

