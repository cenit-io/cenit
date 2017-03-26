module Setup
  class Workflow
    Activity.class_eval do

      register [:join_inclusive, :join_exclusive, :join_parallel], {
        :type => :gateway,
        :inbound_transitions => 100,
        :outbound_transitions => 1,
        :connection_points => 4,
        :background_color => '#ffffe8',
        :stroke_color => '#620000',
        :stroke_width => 2,
        :radio => 25
      }

      def join_inclusive_svg_icon
        gateway_inclusive_svg_icon
      end

      def join_exclusive_svg_icon
        gateway_exclusive_svg_icon
      end

      def join_parallel_svg_icon
        gateway_parallel_svg_icon
      end

    end
  end
end
