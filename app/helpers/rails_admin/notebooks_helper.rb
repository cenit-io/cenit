module RailsAdmin
  ###
  # Features to admin and process the notebooks.
  module NotebooksHelper

    def notebooks_jupyter_url
      login = Account.current || User.current
      base_url = ENV['JUPYTER_NOTEBOOKS_URL'] || "http://127.0.0.1:8888"

      "#{base_url}/tree/#{login.key}/#{login.token}/#{@model_name}"
    end

  end
end

