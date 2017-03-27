module Setup
  class Workflow
    Activity.class_eval do

      def event_svg_icon
        r = Activity::ICON_COORD[:h] / 2
        x = x_coordinate + r
        y = y_coordinate + r

        "<circle cx='#{x}' cy='#{y}' r='#{r}'/>"
      end

    end
  end
end
