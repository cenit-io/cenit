module Cenit
  class Control
    include CanCan::Ability

    attr_reader :app, :action, :controller
    attr_accessor :view

    def initialize(app, controller, action)
      @app = app
      @controller = controller
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

      Struct.new('AppControlAction', *action_hash.keys) unless defined? Struct::AppControlAction
      @action = Struct::AppControlAction.new(*action_hash.values)

      setup_abilities
    end

    def identifier
      @app.slug_id
    end

    def secret_token
      @app.secret_token
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
      when Setup::BaseOauthAuthorization
        if auth.check
          cenit_token = OauthAuthorizationToken.create(application: app, authorization: auth, data: {})
          auth_url = auth.authorize_url(cenit_token: cenit_token)
          cenit_token.save
          controller.session[:oauth_state] = cenit_token.token
          redirect_to auth_url
        else
          fail "Unable to authorize #{auth.custom_title}: #{auth.errors.full_messages.to_sentence}"
        end
      else
        authorize_path = @controller.rails_admin.authorize_path(model_name: auth.class.to_s.underscore.gsub('/', '~'), id: auth.id.to_s)
        redirect_to "#{Cenit.homepage}#{authorize_path}"
      end
    end

    def app_params
      unless @app_params
        @app_params = {}
        @app.parameters.each { |p| @app_params[p.name] = p.value }
      end
      @app_params
    end

    def [](key)
      v = @app.configuration[key]
      v = request_headers[key.to_s] if v.nil?
      v = get_instance_var(key) if v.nil?
      v
    end

    def []=(key, value)
      set_instance_var(key, value)
    end

    def generate_access_token
      unless (app_id = app.application_id)
        fail 'Invalid App, the app identifier ref is broken!'
      end
      unless (access_grant = Cenit::OauthAccessGrant.where(application_id_id: app_id.id).first)
        fail 'No access granted for this App'
      end
      unless (oauth_scope = access_grant.oauth_scope).auth?
        fail 'Granted access does not include the auth scope'
      end
      fail 'Granted access does not include the offline_access scope' unless oauth_scope.offline_access?
      Cenit::OauthAccessToken.for(app_id, access_grant.scope, User.current)
    end

    def xhr?
      @controller.request.xhr?
    end

    def flash
      @controller.flash
    end

    def cache
      @cache_store ||= ActiveSupport::Cache.lookup_store(:file_store, "#{Rails.root}/tmp/cache/#{@app.slug_id}")
    end

    def logger
      Rails.logger
    end

    def fail(*several_variants)
      super
    end

    def application_title
      alg = algorithm(:application_title, false)
      result = alg ? alg.run(self) : false
      result === false ? @app.name : result
    end

    def render_template(name, layout = nil, locals = {})
      if layout.is_a?(Hash)
        locals = layout
        layout = nil
      end
      locals = locals.to_h.symbolize_keys
      layout ||= locals.delete(:layout)

      locals.merge!(control: self)
      content = get_resource(:translator, name).run(locals)
      layout ? get_resource(:translator, layout).run(locals) : content
    end

    def data_type(name, throw = true)
      get_resource(:data_type, name, throw)
    end

    def resource(name, throw = true)
      get_resource(:resource, name, throw)
    end

    def algorithm(name, throw = true)
      get_resource(:algorithm, name, throw)
    end

    def connection(name, throw = true)
      get_resource(:connection, name, throw)
    end

    def data_file(name, throw = true)
      data_type('Files', throw).where(filename: name).first
    end

    def current_user
      alg = algorithm(:current_user, false)
      result = alg ? alg.run(self) : false
      result === false ? @controller.current_user : result
    end

    def app_url(path = nil, params = nil)
      query = params.is_a?(Hash) ? params.to_query() : params.to_s
      url = "#{Cenit.homepage}"
      url << "/app/#{@controller.request.params[:id_or_ns]}"
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

    def get_resource(type, name, throw = true)
      name, ns = parse_resource_name(name)
      item = Cenit.namespace(ns).send(type, name)
      raise "The (#{ns}::#{name}) #{type.to_s.humanize.downcase} was not found." if throw && item.nil?
      item
    end

    def define_helper(name, &block)
      define_singleton_method(name, &block) unless respond_to?(name)
    end

    def instance_var_defined?(name)
      instance_variable_defined?(instance_var_name(name))
    end

    def get_instance_var(name)
      instance_variable_get(instance_var_name(name))
    end

    def set_instance_var(name, value)
      instance_variable_set(instance_var_name(name), value)
    end

    def instance_var(name, &block)
      name = instance_var_name(name)
      instance_variable_set(name, yield) if block_given? && !instance_variable_defined?(name)
      instance_variable_get(name)
    end

    def request_headers
      @controller.request.headers
    end

    def response_headers
      @controller.response.headers
    end

    private

    def instance_var_name(name)
      "@_instance_var_#{name.to_s.gsub(/^@/, '')}".to_sym
    end

    def setup_abilities
      alg = algorithm(:setup_abilities, false)
      alg.run([self, current_user]) if alg.present?
    end

    def parse_resource_name(name)
      name, ns = name.to_s.split(/::|\//).reverse
      ns ||= @app.namespace
      [name, ns]
    end
  end
end