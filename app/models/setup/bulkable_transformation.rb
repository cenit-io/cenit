module Setup
  module BulkableTransformation
    extend ActiveSupport::Concern

    include WithSourceOptions

    included do
      field :bulk_source, type: Boolean

      before_save do
        remove_attribute(:bulk_source) unless bulk_source
        abort_if_has_errors
      end
    end

    def source_key_options
      opts = super
      opts[:bulk] = bulk_source
      opts
    end
  end
end
