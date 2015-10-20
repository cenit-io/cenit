require 'rails'
require 'rails_admin/lib/mongoff_model_config'

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
      RailsAdmin::MongoffModelConfig.new(self)
    end

    def scoped
      model.all
    end

    def properties
      []
    end

    class << self

      def new(m)
        old_new(m)
      end
    end
  end
end

module Mongoff
  class Model

    def accessible_by(ability, action = :index)
      all
    end
  end
end