module Setup
  module ShareWithBindingsAndParameters
    extend ActiveSupport::Concern

    include ShareWithBindings
    include Parameters

    module ClassMethods
      def clear_config_for(tenant, ids)
        super
        Setup::Parameter.reflect_on_all_associations(:belongs_to).each do |r|
          next unless r.klass == self
          tenant.switch do
            Setup::Parameter.where(r.foreign_key.to_sym.in => ids).delete_all
          end
        end
      end
    end
  end
end
