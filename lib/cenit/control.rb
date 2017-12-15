module Cenit
  class Control

    def initialize(app, controller, action)
      @app = app
      @controller = controller
      @cenit_action = action
      params = controller.request.params.merge(action.path_params).with_indifferent_access
      {
         controller: ['app'],
         action: ['index'],
         id_or_ns: [app.slug_id, app.get_identifier, app.ns_slug],
         app_slug: [app.slug]
      }.each do |key, value|
        params.delete(key) if value.include?(params[key])
      end
      @action = Struct.new(http_method: action.method,
                           path: action.request_path,
                           params: params,
                           query_parameters: controller.request.query_parameters,
                           body: controller.request.body,
                           content_type: controller.request.content_type,
                           content_length: controller.request.content_length)
    end

    def identifier
      app.slug_id
    end

    def secret_token
      app.secret_token
    end

    def send_data(*args)
      fail 'Double-rendering' if done?
      @render_called = true
      if args.length == 1 && (res = args[0]).is_a?(Setup::Webhook::HttpResponse)
        controller.send_data res.body, content_type: res.content_type, status: res.code
      else
        controller.send_data(*args)
      end
    end

    def render(*args)
      fail 'Re-calling render' if done?
      @render_called = true
      if args.length == 1 && (res = args[0]).is_a?(Setup::Webhook::HttpResponse)
        if res.headers['content-transfer-encoding']
          controller.send_data res.body, content_type: res.content_type, status: res.code
        else
          controller.render text: res.body, content_type: res.content_type, status: res.code
        end
      else
        controller.render(*args)
      end
    end

    def namespace
      @app.namespace
    end

    def application
      @app.name
    end

    def url_for(path=nil, params=nil)
      query = params.is_a?(Hash) ? params.to_query() : params.to_s
      url = "/app/#{controller.request.params[:id_or_ns]}"
      url << "/#{path}" unless path.blank?
      url << "/#{query}" unless query.blank?
    end

    def render_template(name, locals={})
      get_resource(:translator, name).run(locals.merge(control: self))
    end

    def data_type(name)
      get_resource(:data_type, name)
    end

    def resource(name)
      get_resource(:resource, name)
    end

    def algorithm(name)
      get_resource(:algorithm, name)
    end

    def data_file(name)
      data_type("#{application}-Files").where(filename: name).first
    end

    def method_missing(symbol, *args)
      if (match = symbol.to_s.match(/\Arender_(.+)\Z/))
        render "cenit/#{match[1]}", locals: args[0] || {}, layout: 'cenit'
      else
        super
      end
    end

    def respond_to?(*args)
      args[0].to_s =~ /\Arender_.+\Z/ || super
    end

    def render_called?
      @render_called ||= false
    end

    def base_path
      "/app/#{app.slug_id}"
    end

    def redirect_to(*args)
      fail 'Re-calling redirect_to' if redirect_to_called?
      fail 'Double-rendering' if done?
      @redirect_to_called = true
      if URI.parse(path = args.first).relative?
        path = "#{base_path}/#{path}".gsub(/\/+/, '/')
        args[0] = "#{Cenit.homepage}#{path}"
      end
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

    def app_params
      unless @app_params
        @app_params = {}
        @app.parameters.each { |p| @app_params[p.name] = p.value }
      end
      @app_params
    end

    def [](param)
      @app.configuration[param]
    end

    def access_token_for(auth)
      fail "Invalid authorization class: #{auth.class}" unless auth.is_a?(Setup::Oauth2Authorization)
      unless (app_id = Cenit::ApplicationId.where(identifier: auth.client && auth.client.get_identifier).first)
        fail "Invalid authorization client: #{auth.client.custom_title}"
      end
      scope = auth.scopes.collect { |scope| Cenit::OauthScope.new(scope.name) }.inject(&:merge)
      if scope.valid? && scope.auth?
        Cenit::OauthAccessToken.for(app_id, scope, User.current)
      else
        fail 'Invalid authorization scope'
      end
    end

    attr_reader :action, :app

    private

    attr_reader :controller, :cenit_action

    def parse_resource_name(name)
      name, ns = name.split(/::\//).reverse
      ns ||= @app.namespace
      [name, ns]
    end

    def get_resource(type, name)
      name, ns = parse_resource_name(name)
      item = Cenit.namespace(ns).send(type, name)
      raise "The (#{ns}::#{name}) #{type.humanize.downcase} was not found." unless item
      item
    end

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