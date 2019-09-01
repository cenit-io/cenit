module Cenit
  class Hook
    include Setup::CenitScoped
    include Setup::NamespaceNamed
    include Setup::CustomTitle
    include RailsAdmin::Models::Cenit::HookAdmin

    build_in_data_type

    field :token, type: String
    embeds_many :channels, class_name: Cenit::HookChannel.name, inverse_of: :hook

    accepts_nested_attributes_for :channels, allow_destroy: true

    validates_presence_of :channels

    before_save :ensure_token

    after_save :setup_on_adapter

    def setup_on_adapter
      self.class.adapter.setup_hook(self)
    end

    def ensure_token
      generate_token if token.blank?
      true
    end

    def generate_token
      self.token = Token.friendly(60);
    end

    class << self

      def adapter
        @adapter ||=
          if Cenit::Redis.client?
            RedisAdapter
          else
            MongoidAdapter
          end
      end

      delegate :digest,
               :start,

               to: :adapter

      def setup_tenant(tenant)
        tenant.switch do
          Hook.all.each do |hook|
            adapter.setup_hook(hook, tenant)
          end
        end
      end
    end

    module MongoidAdapter
      extend self

      def setup_hook(_hook, _tenant = Tenant.current)

      end

      def start

      end

      def digest(token, slug, data, content_type)

      end
    end

    module RedisAdapter
      extend self

      def hook_key(token)
        "hook_#{token}"
      end

      def setup_hook(hook, tenant = Tenant.current)
        #TODO Update hook token
        Cenit::Redis.set(hook_key(hook.token), {
          tenant_id: tenant.id.to_s,
          hook_id: hook.id.to_s
        }.to_json)
      end

      def start
        Thread.new do
          Cenit::Redis.new.subscribe(:hook) do |on|
            on.subscribe do |channel, subscriptions|
              puts "Redis Hook adapter subscribed to ##{channel} (#{subscriptions} subscriptions)"
            end

            on.message do |_channel, message|
              message =
                begin
                  JSON.parse(message)
                rescue
                  {}
                end
              token = message['token']
              metadata =
                begin
                  JSON.parse(Cenit::Redis.get(hook_key(token)))
                rescue
                  {}
                end
              if (tenant = Tenant.where(id: metadata['tenant_id']).first)
                message[:hook_id] = metadata['hook_id']
                tenant.owner_switch do
                  Setup::HookDataProcessing.process(message)
                end
              end
            end

            on.unsubscribe do |channel, subscriptions|
              puts "Redis Hook adapter unsubscribed from ##{channel} (#{subscriptions} subscriptions)"
            end
          end
        end
      end

      def digest(token, slug, data, content_type)
        if Cenit::Redis.exists(hook_key(token))
          message = {
            token: token,
            slug: slug,
            data: data,
            content_type: content_type
          }.to_json
          Cenit::Redis.publish(:hook, message)
        else
          false
        end
      end
    end
  end
end