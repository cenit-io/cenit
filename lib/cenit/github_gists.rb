require 'octokit'
require 'forwardable'

module Cenit
  class GithubGists
    extend Forwardable

    def_delegator(:@github, :create_gist)
    def_delegator(:@github, :edit_gist)
    def_delegator(:@github, :delete_gist)

    def initialize(options)
      @github = Octokit::Client.new options
    end
  end
end
