module Setup
  class Event
    include CenitScoped
    include NamespaceNamed
    include ClassHierarchyAware
    include CrossOrigin::CenitDocument

    origins :default, -> { ::User.current_super_admin? ? :admin : nil }

    abstract_class true

    build_in_data_type
      .with(:name)
      .including_polymorphic(:origin)
      .referenced_by(:namespace, :name)
      .and_polymorphic(with_origin: true)
  end
end
