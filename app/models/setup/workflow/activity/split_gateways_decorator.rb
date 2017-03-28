module Setup
  class Workflow
    Activity.class_eval do

      register [:split_inclusive, :split_exclusive, :split_parallel], {
        :type => :gateway,
        :inbound_transitions => 1,
        :outbound_transitions => 100,
        :connection_points => 4,
        :background_color => '#ffffe8',
        :stroke_color => '#80ad40',
        :stroke_width => 2
      }

      def split_inclusive_svg_icon
        gateway_inclusive_svg_icon
      end

      def split_exclusive_svg_icon
        gateway_exclusive_svg_icon
      end

      def split_parallel_svg_icon
        gateway_parallel_svg_icon
      end

      def is_split_conditional?
        self.class.split_conditional_types.include?(self.type)
      end

      def self.split_conditional_types
        %w(split_inclusive split_exclusive)
      end

    end
  end
end
