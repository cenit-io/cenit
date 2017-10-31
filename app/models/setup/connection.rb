module Setup
  class Connection
    include ShareWithBindingsAndParameters
    include NamespaceNamed
    include WithTemplateParameters
    include AuthorizationHandler
    include ModelConfigurable
    include RailsAdmin::Models::Setup::ConnectionAdmin

    build_in_data_type.referenced_by(:namespace, :name).excluding(:connection_roles)
    build_in_data_type.and(
      properties: {
        number: {
          type: 'string'
        },
        token: {
          type: 'string'
        }
      }
    ).protecting(:number, :token)

    field :url, type: String

    parameters :parameters, :headers, :template_parameters

    config_with Setup::ConnectionConfig

    devise :database_authenticatable

    validates_presence_of :url

    def conformed_url(options = {})
      conform_field_value(:url, options)
    end

    class << self

      def respond_to?(*args)
        Setup::Webhook.method_enum.include?(args.first) || super
      end

      def webhook_for(method, url)
        uri = URI.parse(url)
        url = if (path = uri.path).empty?
                path = '/'
                url
              else
                url[0..(url.index(uri.path))]
              end
        connection = Setup::Connection.new(url: url)
        webhook = Setup::PlainWebhook.new(method: method, path: path)
        if (query = uri.query)
          query.split('&').each do |pair|
            Rack::Utils.parse_nested_query(pair).each do |name, value|
              webhook.parameters.new(name: name, value: value)
            end
          end
        end
        webhook.with(connection)
      end

      def method_missing(symbol, *args)
        if Setup::Webhook.method_enum.include?(symbol)
          if args.length == 1 && (url = args[0]).is_a?(String)
            webhook_for(symbol, url)
          else
            fail "Invalid argument #{args} for calling #{symbol} on #{self}"
          end
        else
          super
        end
      end

    end
    
  end
end
