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
        :stroke_width => 4,
        :radio => 25
      }

      def end_event_svg_icon
        event_svg_icon
      end

      def terminate_event_svg_icon
        f = setting[:stroke_color]
        r = setting[:radio] * 2 / 3
        x = self.class::ICON_COORD[:dx] + x_coordinate + r
        y = self.class::ICON_COORD[:dy] + y_coordinate + r

        event_svg_icon + "<circle cx='#{x}' cy='#{y}' r='#{r}' style='fill: #{f}'/>"
      end

      def self.end_event_types
        %w(end_event terminate_event)
      end

    end
  end
end
