module Setup
  class Workflow
    class Transition
      include CenitScoped
      include RailsAdmin::Models::Setup::WorkflowTransitionAdmin

      field :description, type: String
      field :is_default_transition, type: Boolean

      belongs_to :from_activity, :class_name => Setup::Workflow::Activity.name, :inverse_of => :transitions
      belongs_to :to_activity, :class_name => Setup::Workflow::Activity.name, :inverse_of => :in_transitions

      validates_uniqueness_of :to_activity, :scope => :from_activity
      validate :validate_activities

      def name
        "#{from_activity.try(:name) || '...'} => #{to_activity.try(:name) || '...'}"
      end

      def to_svg
        svg = ''

        fa = from_activity
        ta = to_activity

        id_from = "act-#{fa.id}-#{fa.type}"
        id_to = "act-#{ta.id}-#{ta.type}"

        x1, y1, x2, y2 = fa.closest_points(fa.connection_points, ta.connection_points)

        a = (x1 == x2) ? ((y1 > y2) ? -90 : 90) : Math.atan((y2 - y1) / (x2 - x1)) * 180 / Math::PI
        a = 180 + a if (x1 > x2)

        svg << "<line id='tra-line-#{id_from}-#{id_to}' name='connector' x1='#{x1}' y1='#{y1}' x2='#{x2}' y2='#{y2}' stroke-width='3' stroke='#000' from='#{id_from}' to='#{id_to}'/>";
        svg << "<path id='tra-arrow-#{id_from}-#{id_to}' fill='#000' d='m0,0l-10,-5l5,5l-5,5l10,-5z' transform='translate(#{x2} #{y2}) rotate(#{a})'/>";
        # if (is_default_transition && fromActivity instanceof WFActivitySplit && !(fromActivity instanceof WFActivitySplitParallel))
        #   a+=90;
        #   svg << "<path id='tra-default-{id_from}-{id_to}' d='m-5,-5l10,0z' transform='translate(x1 y1) rotate(a)' stroke-width='2' stroke='#000'/>\n";
        # end

        svg
      end

      private

      def validate_activities
        unless to_activity.nil?
          a_errors = from_activity.errors

          if from_activity == to_activity
            errors.add(:to_activity, I18n.t('admin.form.workflow_transition.errors.transition_to_self'))
            a_errors.add(:next_activity_id, I18n.t('admin.form.workflow_transition.errors.transition_to_self'))
          end

          if (new_record? || attribute_changed?(:to_activity)) && !to_activity.has_available_inbounds?
            errors.add(:to_activity, I18n.t('admin.form.workflow_transition.errors.inbound_overflow'))
            a_errors.add(:next_activity_id, I18n.t('admin.form.workflow_transition.errors.inbound_overflow'))
          end
        end
      end

    end
  end
end
