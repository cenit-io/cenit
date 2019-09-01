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
               :setup,

               to: :adapter
    end

    module MongoidAdapter
      extend self

      def setup(tenant)

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

      def setup(tenant)
        tenant.switch do
          Hook.all.each do |hook|
            Cenit::Redis.set(hook_key(hook.token), {
              tenant_id: tenant.id.to_s,
              hook_id: hook.id.to_s
            }.to_json)
          end
        end
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