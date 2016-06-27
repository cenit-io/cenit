module Setup
  module CrossTenancy
    extend ActiveSupport::Concern

    include CrossOriginShared

    included do
      deny :import, :translator_update, :convert, :send_to_flow, :copy, :new, :cross_share #TODO remove :new and :copy from excluded actions when fixing references sharing problem
    end

  end
end