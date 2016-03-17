module Setup
  class Action
    include CenitUnscoped

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    embedded_in :app, class_name: Setup::Application.to_s, inverse_of: :actions

    field :method, type: Symbol
    field :path, type: String, default: '/'

    belongs_to :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil

    validates_presence_of :method, :path, :algorithm
    validates_length_of :path, maximum: 255

    def method_enum
      [:get, :post, :put, :delete, :patch, :copy, :head, :options, :link, :unlink, :purge, :lock, :unlock, :propfind]
    end

    attr_reader :path_params
    attr_reader :request_path

    def match?(path)
      @request_path = path
      @path_params = {}
      tokens = self.path.split('/').from(1)
      path_tokens = path.split('/')
      while tokens.present?
        if (token = tokens.shift) == '*'
          @path_params[:tail] = path_tokens.join('/')
          return true
        else
          return false unless path_tokens.present?
          if token.start_with?(':')
            @path_params[token.from(1).to_sym] = path_tokens.shift
          else
            return false unless token == path_tokens.shift
          end
        end
      end
      path_tokens.blank?
    end

    def run(control)
      params = [control]
      params << path_params if algorithm.parameters.size > 1
      algorithm.run(params)
    end

    def to_s
      "#{method} '#{path}'"
    end
  end
end