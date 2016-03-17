module Cenit
  class Control

    def initialize(app, controller, action)
      @app = app
      @controller = controller
      @action = Struct.new(http_method: action.method,
                           path: action.request_path,
                           params: controller.request.query_parameters.merge(action.path_params),
                           query_parameters: controller.request.query_parameters,
                           body: controller.request.body,
                           content_type: controller.request.content_type,
                           content_length: controller.request.content_length)
    end

    def render(*args)
      fail 'Re-calling render' if render_called?
      @render_called = true
      controller.render(*args)
    end

    def render_called?
      @render_called ||= false
    end

    def redirect_to(*args)
      fail 'Re-calling redirect_to' if redirect_to_called?
      @redirect_to_called = true
      controller.redirect_to(*args)
    end

    def redirect_to_called?
      @redirect_to_called ||= false
    end

    def done?
      redirect_to_called? || render_called?
    end

    def authorize(auth)
      case auth
      when Setup::Oauth2Authorization
        cenit_token = OauthAuthorizationToken.create(application: app, authorization: auth, data: {})
        redirect_to auth.authorize_url(cenit_token: cenit_token)
      else
        redirect_to controller.rails_admin.authorize_path(model_name: auth.class.to_s.underscore.gsub('/', '~'), id: auth.id.to_s)
      end
    end

    attr_reader :action

    private

    attr_reader :app
    attr_reader :controller

    class Struct
      def initialize(hash)
        @hash = hash.symbolize_keys
      end

      def respond_to?(*args)
        @hash.has_key?(args[0])
      end

      def method_missing(symbol, *args)
        if args.length == 0 && @hash.has_key?(symbol)
          @hash[symbol]
        else
          super
        end
      end
    end
  end
end