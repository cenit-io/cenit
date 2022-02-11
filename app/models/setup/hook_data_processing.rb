module Setup
  class HookDataProcessing < Setup::Task

    agent_field :hook

    build_in_data_type

    belongs_to :hook, class_name: Cenit::Hook.to_s, inverse_of: nil

    field :slug, type: String

    before_save do
      self.hook_id ||= message[:hook_id]
      self.slug ||= message[:slug]
    end

    def data
      ::Base64.decode64(message[:data])
    rescue
      message[:data]
    end

    def run(message)
      if (hook = Cenit::Hook.where(id: message[:hook_id]).first)
        slug = message[:slug]
        if (hook_channel = hook.channels.where(slug: slug).first)
          if (data_type = hook_channel.data_type)
            data =
              begin
                ::Base64.decode64(message[:data])
              rescue
                message[:data]
              end
            attachment = {
              filename: 'data',
              body: data,
              contentType: message[:content_type]
            }
            begin
              record = data_type.new_from(data)
              if record
                if record.save
                  Tenant.notify(
                    type: :notice,
                    message: "Record created on hook channel #{hook_channel.label}",
                    attachment: attachment
                  )
                else
                  Tenant.notify(
                    type: :error,
                    message: "Error creating record on hook channel #{hook_channel.label}: #{record.errors.full_messages.to_sentence}",
                    attachment: attachment
                  )
                end
              else
                fail "Unable to parse data"
              end
            rescue Exception => ex
              Tenant.notify(
                type: :error,
                message: "Error creating record on hook channel #{hook_channel.label}: #{ex.message}",
                attachment: attachment
              )
            end
          else
            Tenant.notify(type: :error, message: "No data type defined at channel with slug #{slug}} in hook #{hook.custom_title}")
          end
        else
          Tenant.notify(type: :error, message: "Channel with slug #{slug} not found in hook #{hook.custom_title}")
        end
      else
        Tenant.notify(type: :error, message: "Hook with id #{message[:hook_id]} not found")
      end
    end
  end
end
