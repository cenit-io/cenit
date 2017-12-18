module ActionView
  Base.class_eval do
    def main_app
      controller.try(:main_app)
    end
  end
end