require 'rails_admin/lib/mongoff_attribute_common'

module RailsAdmin
  class MongoffAssociation < RailsAdmin::Adapters::Mongoid::Association

    include RailsAdmin::MongoffAttributeCommon

    def polymorphic?
      false
    end

    def nested_options
      [:embeds_one, :embeds_many].include?(macro.to_sym) ? {allow_destroy: true} : nil
    end

    def association?
      true
    end
  end
end
