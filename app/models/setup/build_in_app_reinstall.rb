module Setup
  class BuildInAppReinstall < Setup::Task

    agent_field :build_in_app, :build_in_app_id

    build_in_data_type

    belongs_to :build_in_app, class_name: Cenit::BuildInApp.to_s, inverse_of: nil

    def run(message)
      if (app = agent_from_msg)
        app_module = app.app_module
        if (tenant = app.tenant)
          begin
            tenant.notify(
              message: "Re-installing buid-in app #{app_module}...",
              type: :info
            )
            tenant.switch do
              app_module.installers.each do |install_block|
                app_module.instance_eval(&install_block)
              end
            end
          rescue Exception => ex
            Setup::SystemNotification.create_from(
              ex, "re-installing build-in app #{app_module}"
            )
            raise ex
          end
        else
          fail "Tenant not found for build-in App ##{build_in_app_id}"
        end
      else
        fail "Build-in App id #{build_in_app_id} not found"
      end
    end
  end
end
