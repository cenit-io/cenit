require 'active_support/concern'

module Hub
  module AfterSave
    extend ActiveSupport::Concern

    included do

      after_create do |object|
        model = object.class.to_s.split('::').last.downcase
        path = 'add_' + model
        Cenit::Middleware::Producer.process(model, object, path)
      end

      after_update do |object|
        model = object.class.to_s.split('::').last.downcase
        path = 'update_' + model
        Cenit::Middleware::Producer.process(model, object, path)
      end

    end

  end
end
