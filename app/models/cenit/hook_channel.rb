module Cenit
  class HookChannel
    include Setup::CenitUnscoped
    include Setup::Slug
    include RailsAdmin::Models::Cenit::HookChannelAdmin

    build_in_data_type

    embedded_in :hook, class_name: Cenit::Hook.name, inverse_of: :channels

    belongs_to :data_type, class_name: Setup::DataType.name, inverse_of: nil

    validates_presence_of :slug, :data_type

    validates_uniqueness_of :slug

    def label
      "#{slug}: #{data_type&.custom_title}"
    end
  end
end