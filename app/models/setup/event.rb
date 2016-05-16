module Setup
  class Event
    include CenitScoped
    include NamespaceNamed
    include ClassHierarchyAware
    include CrossOrigin::Document

    origins -> { Account.current_super_admin? ? :admin : nil }

    abstract_class true

    Setup::Models.exclude_actions_for self

    BuildInDataType.regist(self).with(:name).referenced_by(:namespace, :name)
  end
end
