module Setup
  class Authorization
    include CenitScoped
    include NamespaceNamed
    include ClassHierarchyAware

    abstract_class true

    Setup::Models.exclude_actions_for self

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    def method_missing(symbol, *args)
      if [:each_header, :each_template_parameter].include?(symbol) && block_given?
        self.class.send('auth_' + symbol.to_s.from('each_'.length).pluralize).each do |key, value_access|
          value =
            if value_access.respond_to?(:call)
              value_access.call(self)
            else
              send(value_access)
            end
          yield(key, value)
        end
      else
        super
      end
    end

    class << self

      def method_missing(symbol, *args)
        if [:auth_headers, :auth_template_parameters].include?(symbol)
          ivar = "@#{symbol}".to_sym
          if args.length > 0
            instance_variable_set(ivar, args[0].stringify_keys)
          end
          value = instance_variable_get(ivar) || {}
          if superclass == Object
            value
          else
            superclass.send(symbol).merge(value)
          end
        else
          super
        end
      end
    end

    auth_headers({})
    auth_template_parameters({})
  end
end