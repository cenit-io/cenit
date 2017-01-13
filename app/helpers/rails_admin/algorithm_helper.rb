require 'github_api'
require "base64"

module RailsAdmin
  ###
  # Features to admin and process the algorithms.
  module AlgorithmHelper

    def algorithm_langs
      [
        { id: 'php', label: 'Php', dependencies_file: 'composer.json' },
        { id: 'ruby', label: 'Ruby', dependencies_file: 'Gemfile' },
        { id: 'python', label: 'Python', dependencies_file: 'requirements.txt' },
        { id: 'nodejs', label: 'Nodejs', dependencies_file: 'package.json' },
      ]
    end

    def pull_dependencies(lang)
      contents = Github::Client::Repos::Contents.new(oauth_token: 'c75639235011cb0a7748bed1a1e0ca3facd2f95e')
      user, repo, path = git_params(lang)
      file = contents.find(user, repo, path)
      Base64.decode64(file.content)
    end

    def puch_dependencies(lang, content)
      contents = Github::Client::Repos::Contents.new(oauth_token: 'c75639235011cb0a7748bed1a1e0ca3facd2f95e')
      user, repo, path = git_params(lang)
      file = contents.find(user, repo, path)
      contents.update(user, repo, path, {
        :path => path,
        :message => 'Dependencies updated from Cenit-IO.',
        :content => content.strip,
        :sha => file.sha
      })
    end

    def codemirror_options
      {
        csspath: asset_path('codemirror.css'),
        jspath: asset_path('codemirror.js'),
        options: {
          lineNumbers: true,
          theme: (theme = User.current.try(:code_theme)).present? ? theme : (Cenit.default_code_theme || 'monokai')
        },
        locations: {
          mode: asset_path("codemirror/modes/javascript.js"),
          theme: asset_path("codemirror/themes/monokai.css")
        }
      }
    end

    private

    def git_params(lang)
      ['cenit-io', "cenit-rarg-#{lang[:id]}", lang[:dependencies_file]]
    end

  end
end