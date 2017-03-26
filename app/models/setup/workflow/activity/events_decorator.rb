module Setup
  class Workflow
    Activity.class_eval do

      def event_svg_icon
        r = setting[:radio]
        x = self.class::ICON_COORD[:dx] + x_coordinate + r
        y = self.class::ICON_COORD[:dy] + y_coordinate + r

        "<circle cx='#{x}' cy='#{y}' r='#{r}'/>"
      end

    end
  end
end
