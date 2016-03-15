module Setup
  class Application
    include CenitScoped
    include NamespaceNamed
    include Slug

    BuildInDataType.regist(self).referenced_by(:namespace, :name)

    embeds_many :actions, class_name: Setup::Action.to_s, inverse_of: :application

    accepts_nested_attributes_for :actions
  end
end