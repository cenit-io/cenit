require 'octokit'
require 'rubygems/package'
require 'zlib'
require 'set'
require 'forwardable'
require 'digest/sha1'
require 'rubygems'
require 'open-uri'
require 'zip'

module Cenit

  class GemSynchronizer
    extend Forwardable

    def_delegator(:@github, :delete_repository)
    def_delegator(:'@github.rate_limit', :remaining, :remaining_rest_ops)
    def_delegator(:'@github.rate_limit', :resets_at, :github_service_resets_at)
    def_delegator(:'@github.rate_limit', :resets_in, :github_service_resets_in)

    Tuple3 = Struct.new(:name, :version, :files)

    private

    def get_data_from_gem(file)
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

    def get_data_from_github(file_name)

      url = 'https://github.com/' + @home + file_name + '/archive/master.zip'

      begin
        gem = open(url).read
      rescue => e
        return false
      end

      file = Tempfile.new(file_name)
      file.binmode
      file.write(gem)
      file.rewind

      version = ''
      name = ''
      files_Contents = {}
      files_SHAs = {}

      Zip::File.open(file) do |zip_file|
        zip_file.each do |entry2|
          if entry2.file?
            entry2_content = entry2.get_input_stream.read || ''
            ds = entry2.name.split('/')
            # d1 = ds[0][0..(ds[0].size()-8)]
            fname = ds[1..-1].join('/')
            files_Contents[fname] = entry2_content
            files_SHAs[fname] = Digest::SHA1.hexdigest(entry2_content)
          end
        end
      end

      file.close

      {
        contents: Tuple3.new(name, version, files_Contents),
        hashes: files_SHAs
      }
    end

    # Doing: (content.size) github requests
    def delete_contents(name, content, commit_msg)
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
      sha_new_tree = @github.create_tree(repo, tree, {base_tree: sha_base_tree}).sha
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

    def github_update! (gem_file)
      current_data = get_data_from_gem(gem_file)
      previous_data = get_data_from_github(current_data[:contents][:name])
      actual = current_data[:contents]

      if previous_data
        
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
        if remaining_rest_ops > actual.files.size + 6
          @github.create_repository(actual.name, {auto_init: true})
          push_contents(actual)
        else
          fail 'Github current rate limit exceded.'
        end
      end
    end
  end
end
