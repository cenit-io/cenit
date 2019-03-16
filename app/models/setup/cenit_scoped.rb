module Setup
  module CenitScoped
    extend ActiveSupport::Concern

    include CenitUnscoped
    include AccountScoped

    module ClassMethods
      # def super_count
      #   current_account = Account.current
      #   c = 0
      #   Account.each do |account|
      #     Account.current = account
      #     c += count
      #   end
      #   Account.current = current_account
      #   c
      # end

      def clean_up
        collection.drop
      end
    end
  end
end
