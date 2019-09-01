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
            Cenit::Redis.set(hook_key(hook.token), tenant.id.to_s)
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
              sleep 3
              message =
                begin
                  JSON.parse(message)
                rescue
                  {}
                end
              token = message['token']
              if (tenant = Tenant.where(id: Cenit::Redis.get(hook_key(token))).first)
                tenant.owner_switch do
                  if (hook = Hook.where(token: token).first)
                    slug = message['slug']
                    if (hook_channel = hook.channels.where(slug: slug).first)
                      if (data_type = hook_channel.data_type)
                        data = message['data']
                        attachment = {
                          filename: 'data',
                          body: data,
                          contentType: message['content_type']
                        }
                        begin
                          record = data_type.new_from(data)
                          if record
                            if record.save
                              tenant.notify(
                                type: :notice,
                                message: "Record created on hook channel #{hook_channel.label}",
                                attachment: attachment
                              )
                            else
                              tenant.notify(
                                type: :error,
                                message: "Error creating record on hook channel #{hook_channel.label}: #{record.errors.full_messages.to_sentence}",
                                attachment: attachment
                              )
                            end
                          else
                            fail "Unable to parse data"
                          end
                        rescue Exception => ex
                          tenant.notify(
                            type: :error,
                            message: "Error creating record on hook channel #{hook_channel.label}: #{ex.message}",
                            attachment: attachment
                          )
                        end
                      else
                        tenant.notify(type: :error, message: "No data type defined at channel with slug #{slug}} in hook #{hook.custom_title}")
                      end
                    else
                      tenant.notify(type: :error, message: "Channel with slug #{slug} not found in hook #{hook.custom_title}")
                    end
                  else
                    tenant.notify(type: :error, message: "Hook token #{token} not found")
                  end
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