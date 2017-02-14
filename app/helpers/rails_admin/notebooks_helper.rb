module RailsAdmin
  ###
  # Features to admin and process the notebooks.
  module NotebooksHelper

    def notebooks_jupyter_url
      login = Account.current || User.current
      base_url = ENV['JUPYTER_NOTEBOOKS_URL'] || "http://127.0.0.1:8888"
      ns, model_name = api_model

      if params[:notebook].present?
        nb = Setup::Notebook.find(params[:notebook])
        url = "#{base_url}/notebooks/#{login.key}/#{login.token}/#{nb.path}"
      else
        url = "#{base_url}/tree/#{login.key}/#{login.token}/#{ns}/#{model_name}"
      end

      url
    end

    def new_setup_notebook
      redirect_to rails_admin.notebooks_path(model_name: 'notebook')
    end

    def show_setup_notebook
      model_name = @object.module.gsub(/^setup\//, '')
      model_name = 'notebook' if model_name.empty?
      redirect_to rails_admin.notebooks_path(model_name: model_name, notebook: @object.id)
    end

  end
end

