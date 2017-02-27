require 'rails_admin/config/actions'

module RailsAdmin
  module Config
    module Actions
      class << self
        def all(scope = nil, bindings = {})
          if scope.is_a?(Hash)
            bindings = scope
            scope = :all
          end
          scope ||= :all
          init_actions!
          actions =
            case scope
            when :all
              @@actions
            when :root, :collection, :bulkable, :member, :bulk_processable
              @@actions.select(&:"#{scope}?")
            end
          actions = actions.collect { |action| action.with(bindings) }
          bindings[:controller] ? actions.select(&:visible?) : actions
        end
      end
    end
  end
end