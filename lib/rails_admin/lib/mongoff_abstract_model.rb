require 'rails'
require 'mongoff/model'
require 'mongoff/record'
require 'mongoff/criteria'
require 'rails_admin/lib/mongoff_model_config'
require 'rails_admin/lib/mongoff_property'
require 'rails_admin/lib/mongoff_association'

module RailsAdmin
  class MongoffAbstractModel < AbstractModel

    include RailsAdmin::Adapters::Mongoid

    def initialize(mongoff_model)
      @model = mongoff_model
      @model_name = mongoff_model.to_s
    end

    def model
      @model
    end

    def config
      @config ||= RailsAdmin::MongoffModelConfig.new(self)
    end

    def scoped
      model.all
    end

    def associations
      @associations ||= model.associations.values.collect { |association| RailsAdmin::MongoffAssociation.new(association, model) }
    end

    def embedded_in?(abstract_model = nil)
      abstract_model.nil? ||
        begin
          @embeddors ||= Set.new
          @not_embeddors ||= Set.new
          if @embeddors.include?(abstract_model)
            true
          elsif @not_embeddors.include?(abstract_model)
            false
          elsif abstract_model.model.properties.any? do |property|
            abstract_model.model.property_model(property).eql?(model) &&
              ((referenced = abstract_model.model.property_schema(property)['referenced']).nil? || !referenced)
          end
            @embeddors << abstract_model
            true
          else
            @not_embeddors << abstract_model
            false
          end
        end
    end

    def properties
      unless @properties
        @properties = []
        model.properties.each do |property|
          unless model.property_model?(property)
            @properties << RailsAdmin::MongoffProperty.new(property, model)
          end
        end
      end
      @properties
    end

    class << self

      def new(m)
        unless mongoff_abstract_models = Thread.current[:mongoff_abstract_models]
          Thread.current[:mongoff_abstract_models] = mongoff_abstract_models = {}
        end
        mongoff_abstract_models[m.to_s] ||= old_new(m)
      end

      def abstract_model_for(mongoff_entity)
        if mongoff_entity.is_a?(RailsAdmin::MongoffAbstractModel)
          mongoff_entity
        else
          mongoff_entity = mongoff_entity.orm_model if mongoff_entity.is_a?(Mongoff::Record)
          new(mongoff_entity)
        end
      end
    end
  end
end

module Mongoff
  class Model

    def model_name
      @model_name ||= ActiveModel::Name.new(nil, nil, data_type.name)
    end

    def human_attribute_name(attribute, options = {})
      attribute.to_s.titleize
    end

    def method_defined?(*args)
      property?(args[0])
    end

    def relations
      associations
    end

    def reflect_on_association(name)
      relations[name.to_sym]
    end

  end

  class Record
    def safe_send(key)
      self[key]
    end

    def class
      orm_model
    end

    def associations
      self.class.associations
    end
  end

  class Criteria

    include Kaminari::ConfigurationMethods::ClassMethods
    include Kaminari::MongoidCriteriaMethods
    include Kaminari::PageScopeMethods

    define_method(Kaminari.config.page_method_name) do |num|
      limit(Kaminari.config.default_per_page).offset(Kaminari.config.default_per_page * ([num.to_i, 1].max - 1))
    end

    def embedded?
      false
    end

    def offset_value
      super || 0
    end

    def limit_value
      super || total_count
    end
  end
end