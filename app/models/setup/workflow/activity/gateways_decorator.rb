module Setup
  class Workflow
    Activity.class_eval do

      def gateway_svg_icon
        x = x_coordinate
        y = y_coordinate
        w = h = [self.class::ICON_COORD[:w], self.class::ICON_COORD[:h]].min

        x1 = x + w / 2
        y1 = y
        x2 = x + w
        y2 = y + h / 2
        x3 = x + w / 2
        y3 = y + h
        x4 = x
        y4 = y + h / 2

        "<polygon points='#{x1},#{y1} #{x2},#{y2} #{x3},#{y3} #{x4},#{y4}'/>"
      end

      def gateway_inclusive_svg_icon
        x = x_coordinate
        y = y_coordinate
        w = h = [self.class::ICON_COORD[:w], self.class::ICON_COORD[:h]].min
        sw = setting[:stroke_width] * 2

        # Coordinate of symbol "inclusive (O)"
        cx = x + w / 2
        cy = y + h / 2
        r = [w, h].min / 2 - [w, h].min / 4

        svg = gateway_svg_icon
        svg << "<circle cx='#{cx}' cy='#{cy}' r='#{r}' stroke-width='#{sw}'/>"
      end

      def gateway_exclusive_svg_icon
        x = x_coordinate
        y = y_coordinate
        w = h = [self.class::ICON_COORD[:w], self.class::ICON_COORD[:h]].min
        sw = setting[:stroke_width] * 2

        # Coordinate of symbol "exclusive (X)
        cx = x + w / 2
        cy = y + h / 2
        r = w / 2 * Math.cos(Math::PI / 4) - 3

        rsina = r * Math.sin(Math::PI / 4)
        rcosa = r * Math.cos(Math::PI / 4)

        x1 = cx - rcosa
        y1 = cy - rsina
        x2 = cx + rcosa
        y2 = cy + rsina

        svg = gateway_svg_icon
        svg << "<line x1='#{x1}' y1='#{y1}' x2='#{x2}' y2='#{y2}' stroke-width='#{sw}'/>"
        svg << "<line x1='#{x2}' y1='#{y1}' x2='#{x1}' y2='#{y2}' stroke-width='#{sw}'/>"
      end

      def gateway_parallel_svg_icon
        x = x_coordinate
        y = y_coordinate
        w = h = [self.class::ICON_COORD[:w], self.class::ICON_COORD[:h]].min
        sw = setting[:stroke_width] * 2

        # Coordinate of symbol "parallel (+)"
        x1 = x + w / 7
        y1 = y + h / 2
        x2 = x + w - w / 7
        y2 = y + h / 2

        x3 = x + w / 2
        y3 = y + h / 7
        x4 = x + w / 2
        y4 = y + h - h / 7

        svg = gateway_svg_icon
        svg << "<line x1='#{x1}' y1='#{y1}' x2='#{x2}' y2='#{y2}' stroke-width='#{sw}'/>"
        svg << "<line x1='#{x3}' y1='#{y3}' x2='#{x4}' y2='#{y4}' stroke-width='#{sw}'/>"
      end

    end
  end
end
