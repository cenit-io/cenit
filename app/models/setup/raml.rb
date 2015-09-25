module Setup
  class Raml
    include CenitUnscoped

    Setup::Models.exclude_actions_for self, :new, :edit, :translator_update, :convert, :send_to_flow, :delete_all, :delete, :import

    BuildInDataType.regist(self).referenced_by(:api)

    field :api_name, type: String
    field :api_version, type: String
    field :raml_doc, type: String

    validates_presence_of :api_name, :api_version, :raml_doc
    validates_uniqueness_of :api_name
  end
end