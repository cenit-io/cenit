module ActionView
  Base.class_eval do
    def main_app
      controller.try(:main_app)
    end

    def app_control
      controller.try(:app_control)
    end

    def method_missing(method, *args)
      app_control && app_control.respond_to?(method) ? app_control.send(method, *args) : super(method, *args)
    end

    def respond_to?(method)
      app_control && app_control.respond_to?(method) || super(method)
    end
  end
end