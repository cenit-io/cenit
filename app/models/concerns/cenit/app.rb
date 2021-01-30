module Cenit
  module App
    extend ActiveSupport::Concern

    include Setup::NamespaceNamed
    include Setup::Slug
    include AppConfig
    include AppCommon

  end
end