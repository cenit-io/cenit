module Cenit
  class Control
    include CanCan::Ability

    attr_reader :action, :app, :controller
    attr_accessor :view

    def initialize(app, controller, action)
      @app = app
      @controller = controller
      @cenit_action = action
      params = @controller.request.params.merge(action.path_params).with_indifferent_access

      {
        controller: ['app'],
        action: ['index'],
        id_or_ns: [app.slug_id, app.get_identifier, app.ns_slug],
        app_slug: [app.slug]
      }.each do |key, value|
        params.delete(key) if value.include?(params[key])
      end

      action_hash = {
        http_method: action.method,
        path: action.request_path,
        params: params,
        query_parameters: @controller.request.query_parameters,
        body: @controller.request.body,
        content_type: @controller.request.content_type,
        content_length: @controller.request.content_length,
        name: nil
      }

      Struct.new('Action', *action_hash.keys)
      @action = Struct::Action.new(*action_hash.values)

      setup_abilities
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
        @controller.send_data res.body, content_type: res.content_type, status: res.code
      else
        @controller.send_data(*args)
      end
    end

    def render(*args)
      fail 'Re-calling render' if done?
      @render_called = true
      if args.length == 1 && (res = args[0]).is_a?(Setup::Webhook::HttpResponse)
        if res.headers['content-transfer-encoding']
          @controller.send_data res.body, content_type: res.content_type, status: res.code
        else
          @controller.render text: res.body, content_type: res.content_type, status: res.code
        end
      else
        @controller.render(*args)
      end
    end

    def namespace
      @app.namespace
    end

    def application
      @app.name
    end

    def title
      alg = algorithm(:app_title, false)
      result = alg ? alg.run(self) : false
      result === false ? @app.name : result
    end

    def render_template(name, layout=nil, locals={})
      if layout.is_a?(Hash)
        locals = layout
        layout = nil
      end
      layout ||= locals.delete(:layout)

      locals.merge!(control: self)
      content = get_resource(:translator, name).run(locals)
      layout ? get_resource(:translator, layout).run(locals) : content
    end

    def data_type(name, throw=true)
      get_resource(:data_type, name, throw)
    end

    def resource(name, throw=true)
      get_resource(:resource, name, throw)
    end

    def algorithm(name, throw=true)
      get_resource(:algorithm, name, throw)
    end

    def data_file(name, throw=true)
      data_type('Files', throw).where(filename: name).first
    end

    def current_user
      alg = algorithm(:current_user, false)
      result = alg ? alg.run(self) : false
      result === false ? @controller.current_user : result
    end

    def current_account
      alg = algorithm(:current_account, false)
      result = alg ? alg.run(self) : false
      result === false ? current_user.try(:account) : result
    end

    def app_url(path=nil, params=nil)
      query = params.is_a?(Hash) ? params.to_query() : params.to_s
      url = "/app/#{@controller.request.params[:id_or_ns]}"
      url << "/#{path.gsub(/^\/+|\/+$/, '')}" unless path.blank?
      url << "?#{query}" unless query.blank?
      url
    end

    def sign_in_url(return_to = nil)
      return_to = app_url(return_to) if return_to && URI.parse(return_to).relative?
      return_to ||= app_url(@action.path) if @action.http_method == :get
      alg = algorithm(:sign_in_url, false)
      result = alg ? alg.run(self) : false
      result === false ? @controller.new_user_session_url(return_to: return_to) : result
    end

    def sign_out_url(return_to = nil)
      return_to = app_url(return_to) if return_to && URI.parse(return_to).relative?
      return_to ||= app_url(@action.path) if @action.http_method == :get
      alg = algorithm(:sign_out_url, false)
      result = alg ? alg.run(self) : false
      result === false ? @controller.destroy_user_session_url(return_to: return_to) : result
    end

    def flash
      @controller.flash
    end

    def cache_store
      @cache_store ||= ActiveSupport::Cache.lookup_store(:file_store, "#{Rails.root}/tmp/cache/#{@app.slug_id}")
    end

    def cache(key, options = {}, &block)
      cache_store.fetch(key, options, &block)
    end

    def method_missing(symbol, *args)
      if (match = symbol.to_s.match(/\Arender_(.+)\Z/))
        render "cenit/#{match[1]}", locals: args[0] || {}, layout: 'cenit'
      elsif @controller.respond_to?(symbol)
        @controller.send(symbol, *args)
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
      path = args.first
      if URI.parse(path).relative?
        path = "#{base_path}/#{path}".gsub(/\/+/, '/')
        args[0] = "#{Cenit.homepage}#{path}"
      end
      @controller.redirect_to(*args)
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
        redirect_to @controller.rails_admin.authorize_path(model_name: auth.class.to_s.underscore.gsub('/', '~'), id: auth.id.to_s)
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

    private

    attr_reader :cenit_action

    def setup_abilities
      alg = algorithm(:setup_abilities, false)
      alg.run([self, current_user]) if alg.present?
    end

    def parse_resource_name(name)
      name, ns = name.to_s.split(/::\//).reverse
      ns ||= @app.namespace
      [name, ns]
    end

    def get_resource(type, name, throw=true)
      name, ns = parse_resource_name(name)
      item = Cenit.namespace(ns).send(type, name)
      raise "The (#{ns}::#{name}) #{type.to_s.humanize.downcase} was not found." if throw && item.nil?
      item
    end
  end
end