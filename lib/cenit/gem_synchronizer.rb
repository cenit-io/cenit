require 'octokit'
require 'rubygems/package'
require 'zlib'
require 'set'
require 'forwardable'
require 'digest/sha1'

module Cenit
  class GemSynchronizer
    extend Forwardable

    def_delegator(:@github, :delete_repository)
    def_delegator(:'@github.rate_limit', :remaining, :remaining_rest_ops)
    def_delegator(:'@github.rate_limit', :resets_at, :github_service_resets_at)
    def_delegator(:'@github.rate_limit', :resets_in, :github_service_resets_in)

    Tuple3 = Struct.new(:name, :version, :files)

    private

    def get_data(file)
      version = ''
      name = ''
      files_Contents = {}
      files_SHAs = {}
      Gem::Package::TarReader.new(file) do |tar|
        tar.each do |entry|
          if entry.file?
            if entry.full_name == 'metadata.gz'
              Zlib::GzipReader.wrap(entry) do |gz|
                lines = gz.readlines()
                s = lines[3]
                p = s.index(':')
                version = s[p + 1 .. -1].strip()

                s = lines[1]
                p = s.index(':')
                name = s[p + 1 .. -1].strip()
              end
            else
              if entry.full_name == 'data.tar.gz'
                Zlib::GzipReader.wrap(entry) do |gz|
                  Gem::Package::TarReader.new(gz) do |tar2|
                    tar2.each { |entry2|
                      entry2_content = entry2.read() || ''
                      files_Contents[entry2.full_name] = entry2_content
                      files_SHAs[entry2.full_name] = Digest::SHA1.hexdigest(entry2_content)
                    }
                  end
                end
              end
            end
          end
        end
      end

      {
        contents: Tuple3.new(name, version, files_Contents),
        hashes: files_SHAs
      }
    end

    # Doing: (content.size) github requests
    def delete_contents(name, content, commit_msg)
      puts 'deleting'
      repo = @home + name
      content.each do |path, content1|
        blob_sha1 = @github.create_blob(repo, Base64.encode64(content1), 'base64')
        @github.delete_contents(repo, path, commit_msg, blob_sha1)
      end
    end

    # Make a commit and push it
    #
    # Doing: (data.files.size + 6) github requests
    def push_contents(data)
      repo = @home + data.name
      sha_latest_commit = @github.ref(repo, @ref).object.sha
      sha_base_tree = @github.commit(repo, sha_latest_commit).commit.tree.sha
      tree = []
      data.files.each do |path, content1|
        blob_sha1 = @github.create_blob(repo, Base64.encode64(content1), 'base64')
        tree << {
          path: path, mode: '100644',
          type: 'blob', sha: blob_sha1
        }
      end
      sha_new_tree = @github.create_tree(repo, tree, {:base_tree => sha_base_tree}).sha
      sha_new_commit = @github.create_commit(repo, data.version, sha_new_tree, sha_latest_commit).sha
      @github.update_ref(repo, @ref, sha_new_commit)
      @github.create_ref(repo, 'tags/v' + data.version, sha_new_commit)
    end

    public

    def initialize(repos_home, options)
      @github = Octokit::Client.new options
      @home = repos_home
      @ref = 'heads/master'
    end

    def github_update! (current, previous = nil)
      if previous
        current_data = get_data(current)
        previous_data = get_data(previous)
        actual = current_data[:contents]
        actual_hashes = current_data[:hashes]

        anterior = previous_data[:contents]
        anterior_hashes = previous_data[:hashes]

        a = Set.new(actual.files.keys)
        b = Set.new(anterior.files.keys)

        files_to_delete = anterior.files.select { |k| (b - a).include?(k) }

        data_to_push = actual.clone
        data_to_push.files = actual.files.select { |k| actual_hashes[k] != anterior_hashes[k] }

        if remaining_rest_ops > (data_to_push.files.size + 6 + files_to_delete.size)
          delete_contents(actual.name, files_to_delete, actual.version)
          push_contents(data_to_push)
        else
          fail 'Github current rate limit exceded.'
        end

      else # Create repo and push
        current_data = get_data(current)
        actual = current_data[:contents]

        if remaining_rest_ops > actual.files.size + 6
          @github.create_repository(actual.name, {:auto_init => true})
          push_contents(actual)
        else
          fail 'Github current rate limit exceded.'
        end
      end
    end
  end
end