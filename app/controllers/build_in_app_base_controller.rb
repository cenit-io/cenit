class BuildInAppBaseController < ApplicationController

  before_action :process_headers
  around_action :switch_to_tenant

  def cors_check
    process_headers
    render body: nil
  end

  protected

  def process_headers
    headers.delete('X-Frame-Options')
    headers['Access-Control-Allow-Origin'] = request.headers['Origin'] || ::Cenit.homepage
    headers['Access-Control-Allow-Credentials'] = 'true'
    headers['Access-Control-Allow-Headers'] = request.headers['Access-Control-Request-Headers'] || '*'
    headers['Access-Control-Allow-Methods'] = request.headers['Access-Control-Request-Method'] || Setup::Webhook::METHODS.join(',')
    headers['Access-Control-Max-Age'] = '1728000'
  end

  def app_module
    self.class.app_module
  end

  def app
    @app ||= app_module.app
  end

  def authorize(auth, parameters = {})
    case auth
    when Setup::CallbackAuthorization
      if auth.save
        cenit_token = CallbackAuthorizationToken.create(app_id: app.application_id, authorization: auth, data: {})
        parameters[:cenit_token] = cenit_token
        auth_url = auth.authorize_url(parameters)
        cenit_token.save
        session[:oauth_state] = cenit_token.token
        redirect_to auth_url
      else
        fail "Unable to authorize #{auth.custom_title}: #{auth.errors.full_messages.to_sentence}"
      end
    else
      authorize_path = rails_admin.authorize_path(model_name: auth.class.to_s.underscore.gsub('/', '~'), id: auth.id.to_s)
      redirect_to "#{Cenit.homepage}#{authorize_path}"
    end
  end

  def method_missing(symbol, *args)
    if app.configuration_schema['properties'].key?(symbol.to_s)
      app.configuration[symbol]
    else
      super
    end
  end

  class << self

    def app_module
      @app_module
    end

    def routes
      @routes ||= []
    end

    def route(method, path, options)
      routes << [method, path, options]
    end

    METHODS = %w(get post).map(&:to_sym)

    def method_missing(symbol, *args, &block)
      if METHODS.include?(symbol)
        options =
          if args.length == 1 && block
            base_method_name =
              args[0]
                .split('/')
                .map { |token| token.gsub(/[^a-z,A-Z]/, '') }
                .select { |token| token.length > 0 }
                .join('_')
                .presence
            method_name = base_method_name =
              (base_method_name && "handle_#{base_method_name}") || 'index'
            i_methods = instance_methods(false)
            c = 0
            while i_methods.include?(method_name.to_sym)
              method_name = "#{base_method_name}_#{c += 1}"
            end
            define_method(method_name, &block)
            { to: method_name }
          else
            args[1]
          end
        route(symbol, args[0], options)
      else
        super
      end
    end
  end

  private

  def switch_to_tenant(&block)
    app.tenant.switch(&block)
  end
end
