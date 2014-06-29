require 'active_support/concern'

module Hub
  module AfterSave
    extend ActiveSupport::Concern

    included do

      after_create do |object|
        puts "ESTOY EN EL AFTER CREATE ###################################"
        object_name = object.class.to_s.split('::').last
        path = 'add_' + object_name.downcase
        producer = "Cenit::Middleware::#{object_name}Producer".constantize
        producer.process(object, path)
      end

      after_update do |object|
        object_name = object.class.to_s.split('::').last
        path = 'update_' + object_name.downcase
        producer = "Cenit::Middleware::#{object_name}Producer".constantize
        producer.process(object, path)
      end

    end

  end
end
