module Cenit
  class Control

    attr_reader :app
    attr_reader :controller

    def initialize(app, controller)
      @app = app
      @controller = controller
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
      fail 'Re-calling render' if redirect_to_called?
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
        # amc = RailsAdmin.config(auth.class)
        # am = amc.abstract_model
        # if (authorize_action = v.action(:authorize, am, auth))
        #   task_path = v.show_path(model_name: task.class.to_s.underscore.gsub('/', '~'), id: task.id.to_s)
        #   v.link_to(wording, v.url_for(action: authorize_action.action_name, model_name: am.to_param, id: executor.id, params: { return_to: task_path }))
        #
        # end.html_safe
        render plain: "Authorize not yet supported for #{auth.class}", status: :not_accepted
      end
    end
  end
end