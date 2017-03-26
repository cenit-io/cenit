module Setup
  class Workflow
    Activity.class_eval do

      register [:throw_smtp_message, :throw_http_message], {
        :type => :event,
        :inbound_transitions => 1,
        :outbound_transitions => 1,
        :connection_points => 16,
        :background_color => '#ffe6ff',
        :stroke_color => '#620000',
        :stroke_width => 1,
        :radio => 25
      }

      def intermediate_events_svg_icon
        r = setting[:radio]
        x = self.class::ICON_COORD[:dx] + x_coordinate + r
        y = self.class::ICON_COORD[:dy] + y_coordinate + r

        event_svg_icon + "<circle cx='#{x}' cy='#{y}' r='#{r - 3}'/>"
      end

      def throw_intermediate_events_svg_icon(text)
        svg = intermediate_events_svg_icon
        r = setting[:radio]
        w = 2 * (r - 8) * Math.cos(Math::PI / 6);
        h = 2 * (r - 8) * Math.sin(Math::PI / 6);
        x = self.class::ICON_COORD[:dx] + x_coordinate + r - w / 2;
        y = self.class::ICON_COORD[:dy] + y_coordinate + r - h / 4 * 3;
        sw = setting[:stroke_width]
        sc = setting[:stroke_color]
        bc = setting[:background_color]
        fs = setting[:font_size] || 10

        svg << "<rect x='#{x}' y='#{y}' width='#{w}' height='#{h}' style='stroke: #{bc}; stroke-width: #{sw}; fill: #{sc}'/>"

        x1 = x + 1
        y1 = y
        x2 = x + w / 2
        y2 = y + h / 4 * 3
        x3 = x + w - 1
        y3 = y

        svg << "<polygon points='#{x1},#{y1} #{x2},#{y2} #{x3},#{y3}' style='stroke: #{bc}; stroke-width: #{sw}; fill: #{sc}'/>"

        tx = x
        ty = y + h + fs

        svg << "<text x='#{tx}' y='#{ty}' style='font-size: #{fs}px; stroke: #{sc};'>#{text}</text>"
      end

      def throw_smtp_message_svg_icon
        throw_intermediate_events_svg_icon('SMTP')
      end

      def throw_http_message_svg_icon
        throw_intermediate_events_svg_icon('HTTP')
      end

    end
  end
end
