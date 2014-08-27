require 'active_support/concern'

module Hub
  module AfterSave
    extend ActiveSupport::Concern

    included do

      after_create do |object|
        model = object.class.to_s.split('::').last.downcase
        flows = Setup::Flow.where(model: model, action: 'create')
        flows.each {|f| f.process(object)}
      end

      after_update do |object|
        model = object.class.to_s.split('::').last.downcase
        flows = Setup::Flow.where(model: model, action: 'update')
        flows.each {|f| f.process(object)}
      end

    end

  end
end
