module Setup
  module ShareWithBindingsAndParameters
    extend ActiveSupport::Concern

    include ShareWithBindings
    include Parameters

    module ClassMethods

      def clear_config_for(account, ids)
        super
        if (r = Setup::ParameterConfig.reflect_on_all_associations(:belongs_to).detect { |r| r.klass == self })
          Setup::ParameterConfig.with(account).where(r.foreign_key.to_sym.in => ids).delete_all
        end
      end
    end
  end
end