module RailsAdmin
  ###
  # Features to admin and process the notebooks.
  module NotebooksHelper

    def notebooks_jupyter_url
      login = Account.current || User.current
      base_url = ENV['JUPYTER_NOTEBOOKS_URL'] || "http://127.0.0.1:8888"
      ns, model_name = api_model

      "#{base_url}/tree/#{login.key}/#{login.token}/#{ns}/#{model_name}"
    end

  end
end

