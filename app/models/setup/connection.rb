module Setup
  class Connection
    include ShareWithBindingsAndParameters
    include NamespaceNamed
    include WithTemplateParameters
    include AuthorizationHandler
    include ModelConfigurable
    include RailsAdmin::Models::Setup::ConnectionAdmin

    build_in_data_type.referenced_by(:namespace, :name).excluding(:connection_roles)
    build_in_data_type.and({
                             properties: {
                               number: {
                                 type: 'string'
                               },
                               token: {
                                 type: 'string'
                               }
                             }
                           }.deep_stringify_keys).protecting(:number, :token)

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

      def method_missing(symbol, *args)
        if Setup::Webhook.method_enum.include?(symbol)
          if args.length == 1 && (url = args[0]).is_a?(String)
            uri = URI.parse(url)
            connection = Setup::Connection.new(url: url[0..(url.index(uri.path))])
            webhook = Setup::PlainWebhook.new(method: symbol, path: uri.path)
            if (query = uri.query)
              query.split('&').each do |pair|
                Rack::Utils.parse_nested_query(pair).each do |name, value|
                  webhook.parameters.new(name: name, value: value)
                end
              end
            end

            webhook.with(connection)
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
