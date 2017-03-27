module Setup
  class Workflow
    Activity.class_eval do

      def to_svg
        send("#{type.to_s}_svg_icon")
      end

      def is_overlap?(act)
        act.id != self.id && act.x_coordinate == self.x_coordinate && act.y_coordinate == self.y_coordinate
      end

      def connection_points
        method = "#{type.to_s}_connection_points"
        return send(method) if respond_to?(method)

        r = setting[:radio]
        x = self.class::ICON_COORD[:dx] + x_coordinate + r
        y = self.class::ICON_COORD[:dy] + y_coordinate + r

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
