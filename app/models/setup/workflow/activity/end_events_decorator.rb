module Setup
  class Workflow
    Activity.class_eval do

      register [:end_event, :terminate_event], {
        :type => :event,
        :inbound_transitions => 1,
        :outbound_transitions => 0,
        :connection_points => 16,
        :background_color => '#ffe6ff',
        :stroke_color => '#620000',
        :stroke_width => 4
      }

      def end_event_svg_icon
        event_svg_icon
      end

      def terminate_event_svg_icon
        f = setting[:stroke_color]
        r = Activity::ICON_COORD[:h] / 3
        x = x_coordinate + r
        y = y_coordinate + r

        event_svg_icon + "<circle cx='#{x}' cy='#{y}' r='#{r}' style='fill: #{f}'/>"
      end

      def self.end_event_types
        [:end_event, :terminate_event]
      end

    end
  end
end
