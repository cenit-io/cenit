module Setup
  class Workflow
    Activity.class_eval do

      after_save :check_position

      def icon
        send("#{type.to_s}_icon")
      end

      def check_position()
        items = workflow.activities.where(:x_coordinate => x_coordinate, :y_coordinate => y_coordinate).to_a
        c = items.select { |a| a.id != id }.count

        if (c > 0)
          self.y_coordinate += 50 * c
          save()
        end
      end

    end
  end
end
