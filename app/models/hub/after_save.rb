require 'active_support/concern'

module Hub
  module AfterSave
    extend ActiveSupport::Concern

    included do

      after_create do |object|
        path = 'add_' + object.class.to_s.downcase.split('::').last
        Cenit::Middleware::Producer.process(object, path, false)
      end

      after_update do |object|
        path = 'update_' + object.class.to_s.downcase.split('::').last
        Cenit::Middleware::Producer.process(object, path, true)
      end

    end

  end
end
