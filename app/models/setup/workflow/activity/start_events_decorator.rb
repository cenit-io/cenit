module Setup
  class Workflow
    Activity.class_eval do

      register :start_event, {
        :type => :event,
        :inbound_transitions => 0,
        :outbound_transitions => 1,
        :connection_points => 16,
        :background_color => '#f0ffc8',
        :stroke_color => '#80ad40',
        :stroke_width => 2,
        :radio => 25
      }

      def start_event_svg_icon
        event_svg_icon
      end

      def self.start_event_types
        %w(start_event)
      end
    end
  end
end
