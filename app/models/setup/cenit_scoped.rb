module Setup
  module CenitScoped
    extend ActiveSupport::Concern

    include CenitUnscoped
    include AccountScoped

  end
end
