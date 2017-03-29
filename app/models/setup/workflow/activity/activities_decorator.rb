module Setup
  class Workflow
    Activity.class_eval do

      def to_svg
        svg = "<g id='#{type}-#{id}' style='stroke: #{setting[:stroke_color]}; stroke-width: #{setting[:stroke_width]}; fill: #{setting[:background_color]};'>"
        svg << send("#{type.to_s}_svg_icon")
        svg << "</g>"
      end

      def icon
        m = Activity::ICON_COORD[:m] / 2
        vbw = Activity::ICON_COORD[:w] + m * 2
        vbh = Activity::ICON_COORD[:h] + m * 2
        dx = -1 * (x_coordinate - m)
        dy = -1 * (y_coordinate - m)

        svg = "<svg viewBox='0 0 #{vbw} #{vbh}' width='72' height='36' xmlns:xlink='http://www.w3.org/1999/xlink' xmlns='http://www.w3.org/2000/svg' xmlns:se='http://svg-edit.googlecode.com'>"
        svg << "<g transform='scale(1),translate(#{dx},#{dy})' style='stroke: black; fill: #FFFFFF;' transform='translate(2,2)'>"
        svg << "<title>#{type.to_s.humanize} (#{name})</title>"
        svg << to_svg
        svg << "</g>"
        svg << "</svg>"
      end

      def is_overlap?(act)
        act.id != self.id && act.x_coordinate == self.x_coordinate && act.y_coordinate == self.y_coordinate
      end

      def connection_points
        method = "#{type.to_s}_connection_points"
        return send(method) if respond_to?(method)

        r = Activity::ICON_COORD[:h] / 2
        x = x_coordinate + r
        y = y_coordinate + r

        cpi = 2 * Math::PI / setting[:connection_points]

        setting[:connection_points].times.map do |i|
          angle = cpi * i
          { :x => x + r * Math.cos(angle), :y => y + r * Math.sin(angle) }
        end
      end

      def closest_points(cp1, cp2)
        d1 = -1
        closest_point = nil

        cp1.each do |p1|
          cp2.each do |p2|
            d2 = Math.sqrt((p1[:x] - p2[:x])**2 + (p1[:y] - p2[:y])**2)
            if d1 == -1 || d1 > d2
              d1 = d2
              closest_point = [p1[:x], p1[:y], p2[:x], p2[:y]]
            end
          end
        end

        closest_point
      end

    end
  end
end
