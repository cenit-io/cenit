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

    class MongoidAdapter
      include Mongoid::Document

      field :_id, type: String
      field :hook_id
      belongs_to :tenant, class_name: Tenant.name, inverse_of: nil

      class << self

        def setup_hook(hook, tenant = Tenant.current)
          if (record = where(hook_id: hook.id, tenant_id: tenant.id).first)
            unless record.id == hook.token
              record.delete
              record = nil
            end
          end
          create(id: hook.token, hook_id: hook.id, tenant_id: tenant.id) unless record
        end

        def start
        end

        def digest(token, slug, data, content_type)
          if (tenant = where(id: token)&.first&.tenant)
            tenant.owner_switch do
              if (hook = Hook.where(token: token).first)
                message = {
                  hook_id: hook.id,
                  token: token,
                  slug: slug,
                  data: data,
                  content_type: content_type
                }
                Setup::HookDataProcessing.process(message)
                true
              else
                false
              end
            end
          else
            false
          end
        end
      end
    end

    module RedisAdapter
      extend self

      HOOK_PREFIX = 'hook_'

      def hook_key(token)
        "#{HOOK_PREFIX}#{token}"
      end

      def hook_token_key(tenant)
        "#{HOOK_PREFIX}token_#{tenant[:id]}"
      end

      def setup_hook(hook, tenant = Tenant.current)
        hook_token_key = self.hook_token_key(tenant)
        registered_token = Cenit::Redis.get(hook_token_key)
        hook_key = self.hook_key(registered_token)
        unless registered_token == hook.token
          Cenit::Redis.del(hook_key)
          Cenit::Redis.set(hook_token_key, hook.token)
          hook_key = self.hook_key(hook.token)
        end
        Cenit::Redis.set(hook_key, {
          tenant_id: tenant.id.to_s,
          hook_id: hook.id.to_s
        }.to_json)
      end

      def start
        Cenit::Redis.del("#{HOOK_PREFIX}*")
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