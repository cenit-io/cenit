require 'mongoid/history/trackable'
require 'mongoid/history/tracker'


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

        def undo(modifier = nil, options_or_version = nil)
          versions = get_versions_criteria(options_or_version).to_a
          versions.sort! { |v1, v2| v2.version <=> v1.version }

          versions.each do |v|
            #Patch
            v.root_document = self
            undo_attr = v.undo_attr(modifier)
            if Mongoid::History.mongoid3? # update_attributes! not bypassing rails 3 protected attributes
              assign_attributes(undo_attr, without_protection: true)
            else # assign_attributes with 'without_protection' option does not work with rails 4/mongoid 4
              self.attributes = undo_attr
            end
          end
        end

        def track_history?
          self.class.track_history?
        end
      end
    end

    module Tracker

      attr_accessor :root_document

      private

      def traverse_association_chain
        chain = association_chain.dup
        doc = nil
        documents = []
        loop do
          node = chain.shift
          name = node['name']
          doc = if doc.nil?
                  #Patch
                  if root_document && root_document.id == node['id']
                    root_document
                  else
                    # root association. First element of the association chain
                    # unscoped is added to remove any default_scope defined in model
                    klass = name.classify.constantize
                    klass.unscoped.where(_id: node['id']).first
                  end
                elsif doc.class.embeds_one?(name)
                  doc.get_embedded(name)
                elsif doc.class.embeds_many?(name)
                  doc.get_embedded(name).unscoped.where(_id: node['id']).first
                else
                  fail 'This should never happen. Please report bug.'
                end
          documents << doc
          break if chain.empty?
        end
        documents
      end
    end
  end
end

require 'mongoid-audit/history_tracker'

class HistoryTracker
  include CrossOrigin::Document
  store_in collection: -> { "#{persistence_model.collection_name.to_s.singularize}_history_trackers" }

  origins -> { persistence_model.origins }

  class << self

    def persistence_model
      (persistence_options && persistence_options[:model]) || fail('Persistence option model is missing')
    end

    def storage_options_defaults
      opts = super
      if persistence_options && (model = persistence_options[:model])
        opts[:collection] = "#{model.storage_options_defaults[:collection].to_s.singularize}_history_trackers"
      end
      opts
    end

    def with(options)
      options = { model: options } unless options.is_a?(Hash)
      super
    end
  end
end