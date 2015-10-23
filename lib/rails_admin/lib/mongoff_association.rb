require 'rails_admin/lib/mongoff_attribute_common'

module RailsAdmin
  class MongoffAssociation < RailsAdmin::Adapters::Mongoid::Association

    include RailsAdmin::MongoffAttributeCommon

    def schema
      model.schema
    end

    def polymorphic?
      false
    end

    def nested_options
      {allow_destroy: true}
    end

    def association?
      true
    end
  end
end
