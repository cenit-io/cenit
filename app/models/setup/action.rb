module Setup
  class Action
    include CenitUnscoped
    # = Action
    #
    # Actions HTTP Method.

    METHODS = [:get, :post, :put, :delete, :patch, :copy, :head, :options, :link, :unlink, :purge, :lock, :unlock, :propfind]

    build_in_data_type.referenced_by(:method, :path).and(
      label: '{{method | upcase}} {{path}}',
      properties: {
        method: {
          enum: METHODS.map(&:to_s)
        }
      }
    )

    embedded_in :app, class_name: Setup::Application.to_s, inverse_of: :actions

    field :method, type: StringifiedSymbol
    field :path, type: String, default: '/'
    field :priority, type: Integer, default: 0

    belongs_to :algorithm, class_name: Setup::Algorithm.to_s, inverse_of: nil

    before_validation do
      self.path ||= '/'
      self.path = "/#{path}" unless path.start_with?('/')
    end

    validates_presence_of :method, :algorithm, :path
    validates_length_of :path, maximum: 255
    validates_format_of :path, with: %r{\A(\/:?(\w|-)+)*(\/(\*)?)?\Z}

    def method_enum
      METHODS
    end

    attr_reader :path_params, :request_path, :control

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
      @control = control
      params = [control]
      params << control.action.params if algorithm.parameters.size > 1
      algorithm.with_linker(self).run(params)
    end

    def link?(call_symbol)
      algorithm.link?(call_symbol) || control[call_symbol]
    end

    def link(call_symbol)
      unless (alg =algorithm.link(call_symbol))
        alg =
          if (record = control[call_symbol]).is_a?(Setup::Algorithm)
            record
          else
            -> { record }
          end
      end
      alg
    end

    def linker_id
      'a' + id.to_s
    end

    def to_s
      "#{method} '#{path}'"
    end

  end
end
