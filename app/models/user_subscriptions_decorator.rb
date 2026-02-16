class UserSubscriptionsDecorator
  def self.apply
    return unless defined?(User)

    User.class_eval do
      def customers
        @customers ||= app_subscriptions_request(:customers)
      end

      def subscriptions
        @subscriptions ||= app_subscriptions_request(:subscriptions)
      end

      private

      def app_subscriptions_request(resource)
        return unless ENV['SUBSCRIPTIONS_APP'].present?

        home_url = Cenit.homepage
        app_slug = ENV['SUBSCRIPTIONS_APP']
        options = { query: { limit: 20, format: 'json' } }

        http_response = HTTMultiParty.get("#{home_url}/app/#{app_slug}/#{resource}", options)
        http_response.parsed_response.deep_symbolize_keys
      end
    end
  end
end

UserSubscriptionsDecorator.apply
