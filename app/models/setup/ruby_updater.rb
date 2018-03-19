module Setup
  class RubyUpdater < UpdaterTransformation
    include WithSourceOptions
    include RubyCodeTransformation
    include RailsAdmin::Models::Setup::RubyUpdaterAdmin

    field :source_handler, type: Boolean

    def validates_configuration
      remove_attribute(:source_handler) unless source_handler
      super
    end

    def source_key_options
      opts = super
      opts.merge!(
        data_type_key: :target_data_type,
        sources_key: :targets,
        source_key: :target,
        bulk: source_handler
      )
      opts
    end
  end
end
