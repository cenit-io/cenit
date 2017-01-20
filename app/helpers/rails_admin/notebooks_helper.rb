require 'github_api'

module RailsAdmin
  ###
  # Features to admin and process the notebooks.
  module NotebooksHelper

    def notebook_get(id)
      github = Github.new(oauth_token: ENV['GITHUB_OAUTH_TOKEN'])
      github.gists.get(id)
    rescue Github::Error::NotFound
      nil
    end

    def notebook_create(name, description, files, notebook = nil)
      github = Github.new(oauth_token: ENV['GITHUB_OAUTH_TOKEN'])
      gist = github.gists.create(
        description: description,
        public: false,
        files: files
      )

      unless notebook.nil?
        notebook.gist_id = gist.id
        notebook.save!
      else
        Setup::Notebook.create(name: name, gist_id: gist.id)
      end

      gist
    end

    def notebook_update(notebook, description, files)
      github = Github.new(oauth_token: ENV['GITHUB_OAUTH_TOKEN'])
      gist = github.gists.edit(notebook.gist_id, {
        description: description,
        public: false,
        files: files
      })

      [gist, notebook]
    end

    def notebook_find_or_create()
      ns, model_name, display_name = api_model
      name = "#{ns}/#{model_name}".strip
      desc = "How to manage #{display_name.pluralize} in Cenit-IO."
      prefix = "cenit-io.#{name.parameterize}"
      files = api_markdowns.map { |c| ["#{prefix}-[#{c[:lang][:id]}].md", { content: c[:content] }] }.to_h

      notebook = Setup::Notebook.where(:name => name).first
      if notebook.nil?
        notebook_create(name, desc, files)
      else
        notebook_get(notebook.gist_id) || notebook_create(name, desc, files, notebook)
      end
    end

  end
end

