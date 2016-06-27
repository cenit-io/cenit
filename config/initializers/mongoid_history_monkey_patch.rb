module Mongoid
  module History
    module Trackable
      extend ActiveSupport::Concern

      module ClassMethods
        def track_history(options = {})
          scope_name = collection_name.to_s.singularize.to_sym
          default_options = {
            on: :all,
            except: [:created_at, :updated_at],
            modifier_field: :modifier,
            version_field: :version,
            changes_method: :changes,
            scope: scope_name,
            track_create: false,
            track_update: true,
            track_destroy: false
          }

          options = default_options.merge(options)

          # normalize :except fields to an array of database field strings
          options[:except] = [options[:except]] unless options[:except].is_a? Array
          options[:except] = options[:except].map { |field| database_field_name(field) }.compact.uniq

          # normalize :on fields to either :all or an array of database field strings
          if options[:on] != :all
            options[:on] = [options[:on]] unless options[:on].is_a? Array
            options[:on] = options[:on].map { |field| database_field_name(field) }.compact.uniq
          end

          field options[:version_field].to_sym, type: Integer

          belongs_to_modifier_options = { class_name: Mongoid::History.modifier_class_name }
          belongs_to_modifier_options[:inverse_of] = options[:modifier_field_inverse_of] if options.key?(:modifier_field_inverse_of)
          belongs_to options[:modifier_field].to_sym, belongs_to_modifier_options

          include MyInstanceMethods
          extend SingletonMethods

          delegate :history_trackable_options, to: 'self.class'
          # Patch
          # delegate :track_history?, to: 'self.class'

          before_update :track_update if options[:track_update]
          before_create :track_create if options[:track_create]
          before_destroy :track_destroy if options[:track_destroy]

          Mongoid::History.trackable_class_options ||= {}
          Mongoid::History.trackable_class_options[scope_name] = options
        end
      end

      module MyInstanceMethods
        def track_history?
          self.class.track_history?
        end
      end
    end
  end
end